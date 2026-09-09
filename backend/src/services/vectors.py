import asyncio
import logging
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
    "projects": ["project"],
    "experience": ["role"],
    "skills": ["skill"],
}

_ready = False


@cache
def client() -> QdrantClient:
    return QdrantClient(
        url=settings.QDRANT_URL,
        api_key=settings.QDRANT_API_KEY or None,
        timeout=20,
    )


def ready() -> bool:
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
        return await _context(question, limit)
    except Exception:
        log.exception("retrieval failed, answering without it")
        return []


async def _context(question: str, limit: int) -> list[dict]:
    if not _ready:
        return []
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
            "text": (hit.payload or {}).get("text"),
            "score": hit.score,
        }
        for hit in found.points
    ]
