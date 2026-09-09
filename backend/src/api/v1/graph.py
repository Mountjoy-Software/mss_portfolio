from fastapi import APIRouter, HTTPException, Query

from src.config import settings
from src.services import vectors

router = APIRouter()


@router.get("/graph/seed")
async def seed() -> dict:
    if not vectors.ready():
        raise HTTPException(503, "The index is still building. Try again shortly.")
    return {"nodes": await vectors.seed(), "collection": vectors.COLLECTION}


@router.get("/graph/expand/{point_id}")
async def expand(
    point_id: str,
    limit: int = Query(default=settings.GRAPH_EXPAND_LIMIT, ge=1, le=12),
) -> dict:
    if not vectors.ready():
        raise HTTPException(503, "The index is still building. Try again shortly.")
    neighbours = await vectors.expand(point_id, limit)
    if not neighbours:
        return {"nodes": []}
    return {"nodes": neighbours}
