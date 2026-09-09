import asyncio
import logging
import time
import uuid
from functools import cache

from qdrant_client import QdrantClient
from qdrant_client.models import (
    Distance,
    FieldCondition,
    Filter,
    HasIdCondition,
    MatchAny,
    MatchValue,
    PayloadSchemaType,
    PointStruct,
    VectorParams,
)

from src.config import settings
from src.content import profile
from src.services import corpus, embeddings

log = logging.getLogger(__name__)

COLLECTION = "portfolio"
_META_ID = str(uuid.uuid5(uuid.NAMESPACE_URL, "mss:portfolio:meta"))

MEMBERS = {
    "about": ["bio", "education"],
    "projects": ["project"],
    "experience": ["role"],
    "skills": ["skill"],
}

_ready = False
_failure: str | None = None
_last_attempt = 0.0
_lock = asyncio.Lock()
_RETRY_AFTER = 30.0


@cache
def client() -> QdrantClient:
    return QdrantClient(
        url=settings.QDRANT_URL,
        api_key=settings.QDRANT_API_KEY or None,
        timeout=20,
    )


def ready() -> bool:
    return _ready


def status() -> str:
    if _ready:
        return "ready"
    if _failure:
        return f"The vector index could not be built: {_failure}"
    return "The vector index is still building. Try again shortly."


async def ensure_ready() -> bool:
    global _last_attempt
    if _ready:
        return True
    async with _lock:
        if _ready:
            return True
        now = time.monotonic()
        if now - _last_attempt < _RETRY_AFTER:
            return False
        _last_attempt = now
        try:
            await ensure_index()
        except Exception:
            log.exception("index rebuild attempt failed")
    return _ready


def _stored_fingerprint() -> str | None:
    found = client().retrieve(COLLECTION, ids=[_META_ID], with_payload=True)
    if not found:
        return None
    return (found[0].payload or {}).get("fingerprint")


def _create() -> None:
    client().create_collection(
        COLLECTION,
        vectors_config=VectorParams(
            size=settings.EMBED_DIMENSIONS, distance=Distance.COSINE
        ),
    )
    client().create_payload_index(
        COLLECTION, field_name="kind", field_schema=PayloadSchemaType.KEYWORD
    )


async def ensure_index() -> None:
    global _ready, _failure
    try:
        await _build()
    except Exception as error:
        _failure = f"{type(error).__name__}"
        raise
    _failure = None


async def _build() -> None:
    global _ready
    docs = corpus.build(profile())
    fingerprint = corpus.fingerprint(docs)

    exists = await asyncio.to_thread(client().collection_exists, COLLECTION)
    if exists:
        current = await asyncio.to_thread(_stored_fingerprint)
        if current == fingerprint:
            _ready = True
            log.info("vector index already current at %s", fingerprint)
            return
        await asyncio.to_thread(client().delete_collection, COLLECTION)

    await asyncio.to_thread(_create)

    vectors = await embeddings.embed_all([doc.text for doc in docs])
    points = [
        PointStruct(
            id=doc.point_id,
            vector=vector,
            payload={
                "kind": doc.kind,
                "title": doc.title,
                "text": doc.text,
                **doc.payload,
            },
        )
        for doc, vector in zip(docs, vectors)
    ]
    points.append(
        PointStruct(
            id=_META_ID,
            vector=[0.0] * settings.EMBED_DIMENSIONS,
            payload={"kind": "meta", "fingerprint": fingerprint},
        )
    )

    await asyncio.to_thread(
        client().upsert, collection_name=COLLECTION, points=points, wait=True
    )
    _ready = True
    log.info("vector index built: %d points at %s", len(points), fingerprint)


def _node(point) -> dict:
    payload = dict(point.payload or {})
    payload.pop("text", None)
    return {
        "id": str(point.id),
        "score": getattr(point, "score", None),
        **payload,
    }


async def seed() -> list[dict]:
    found = await asyncio.to_thread(
        client().query_points,
        collection_name=COLLECTION,
        query=[0.0] * settings.EMBED_DIMENSIONS,
        query_filter=Filter(
            must=[FieldCondition(key="kind", match=MatchValue(value="category"))]
        ),
        limit=len(corpus.CATEGORIES),
        with_payload=True,
    )
    return [_node(point) for point in found.points]


async def expand(point_id: str, limit: int) -> list[dict]:
    origin = await asyncio.to_thread(
        client().retrieve,
        collection_name=COLLECTION,
        ids=[point_id],
        with_payload=True,
        with_vectors=True,
    )
    if not origin:
        return []

    point = origin[0]
    payload = point.payload or {}
    kinds = MEMBERS.get(payload.get("category", ""), [])

    conditions = [HasIdCondition(has_id=[point_id])]
    if kinds:
        must = [FieldCondition(key="kind", match=MatchAny(any=kinds))]
    else:
        must = None
        conditions.append(
            FieldCondition(key="kind", match=MatchAny(any=["category", "meta"]))
        )

    found = await asyncio.to_thread(
        client().query_points,
        collection_name=COLLECTION,
        query=point.vector,
        query_filter=Filter(must=must, must_not=conditions),
        limit=limit,
        with_payload=True,
    )
    return [_node(hit) for hit in found.points]


async def context(question: str, limit: int) -> list[dict]:
    try:
        if not await ensure_ready():
            return []
        return await _context(question, limit)
    except Exception:
        log.exception("retrieval failed, answering without it")
        return []


async def _context(question: str, limit: int) -> list[dict]:
    vector = await embeddings.embed(question)
    found = await asyncio.to_thread(
        client().query_points,
        collection_name=COLLECTION,
        query=vector,
        query_filter=Filter(
            must_not=[
                FieldCondition(key="kind", match=MatchAny(any=["category", "meta"]))
            ]
        ),
        limit=limit,
        with_payload=True,
    )
    return [
        {
            "kind": (hit.payload or {}).get("kind"),
            "title": (hit.payload or {}).get("title"),
            "text": _with_references(hit.payload or {}),
            "score": hit.score,
        }
        for hit in found.points
    ]


def _with_references(payload: dict) -> str:
    lines = [payload.get("text") or ""]
    for label, key in (("Repository", "repo"), ("Live", "url"), ("Deck", "deck")):
        if payload.get(key):
            lines.append(f"{label}: {payload[key]}")
    media = payload.get("media") or []
    if media:
        lines.append("Images: " + ", ".join(media))
    return "\n".join(lines)
