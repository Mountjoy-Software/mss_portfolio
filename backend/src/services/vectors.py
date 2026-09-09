import asyncio
import logging
import time
import uuid
from dataclasses import dataclass
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
    "skills": ["skill_group"],
}


@dataclass(frozen=True)
class Link:
    kind: str
    relation: str
    limit: int = 6
    match: tuple[str, ...] = ()
    listed: tuple[str, str] | None = None


LINKS = {
    "project": [
        Link("skill", "its stack, closest first", 6, listed=("stack", "title")),
        Link("skill", "nearest other skills", 2),
        Link("role", "nearest role", 1),
    ],
    "role": [
        Link("highlight", "what shipped in the role", 8, match=("company", "role")),
        Link("skill", "its stack, closest first", 6, listed=("stack", "title")),
        Link("project", "nearest projects", 2),
    ],
    "highlight": [
        Link("skill", "nearest skills", 4),
        Link("project", "nearest projects", 2),
    ],
    "skill_group": [
        Link("skill", "skills in the group, closest first", 14, match=("group",))
    ],
    "skill": [
        Link("project", "projects listing it", 6, listed=("title", "stack")),
        Link("role", "roles listing it", 4, listed=("title", "stack")),
        Link("highlight", "nearest work", 2),
    ],
    "bio": [
        Link("role", "roles held", 4),
        Link("education", "education", 2),
    ],
    "education": [Link("skill", "nearest skills", 4)],
}

INDEXED = ("kind", "group", "company", "role", "title", "stack")

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
    _index_payload()


def _index_payload() -> None:
    for name in INDEXED:
        client().create_payload_index(
            COLLECTION, field_name=name, field_schema=PayloadSchemaType.KEYWORD
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
            await asyncio.to_thread(_index_payload)
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


def _expands(payload: dict) -> str:
    if payload.get("kind") == "category":
        return "its members"
    return ", ".join(link.relation for link in LINKS.get(payload.get("kind"), []))


def _node(point) -> dict:
    payload = dict(point.payload or {})
    payload.pop("text", None)
    return {
        "id": str(point.id),
        "score": getattr(point, "score", None),
        "expands": _expands(payload),
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


async def expand(point_id: str) -> list[dict]:
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
    if payload.get("kind") == "category":
        kinds = MEMBERS.get(payload.get("category", ""), [])
        links = [Link(kind, "members", 40) for kind in kinds]
    else:
        links = LINKS.get(payload.get("kind", ""), [])

    nodes = []
    seen = [point_id]
    for link in links:
        must = [FieldCondition(key="kind", match=MatchValue(value=link.kind))]
        for key in link.match:
            if payload.get(key) is None:
                break
            must.append(
                FieldCondition(key=key, match=MatchValue(value=payload[key]))
            )
        else:
            if link.listed:
                source, target = link.listed
                values = payload.get(source)
                values = values if isinstance(values, list) else [values]
                values = [v for v in values if v]
                if not values:
                    continue
                must.append(
                    FieldCondition(key=target, match=MatchAny(any=values))
                )
            found = await asyncio.to_thread(
                client().query_points,
                collection_name=COLLECTION,
                query=point.vector,
                query_filter=Filter(
                    must=must, must_not=[HasIdCondition(has_id=seen)]
                ),
                limit=link.limit,
                with_payload=True,
            )
            for hit in found.points:
                nodes.append({**_node(hit), "relation": link.relation})
                seen.append(str(hit.id))
    return nodes


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
