from fastapi import APIRouter, HTTPException

from src.services import vectors

router = APIRouter()


async def _require_index() -> None:
    if not await vectors.ensure_ready():
        raise HTTPException(503, vectors.status())


@router.get("/graph/seed")
async def seed() -> dict:
    await _require_index()
    return {"nodes": await vectors.seed(), "collection": vectors.COLLECTION}


@router.get("/graph/expand/{point_id}")
async def expand(point_id: str) -> dict:
    await _require_index()
    return {"nodes": await vectors.expand(point_id)}
