from fastapi import APIRouter, Request

from src.security import request_ip
from src.services import threads

router = APIRouter()


@router.get("/visitor")
async def visitor(request: Request) -> dict:
    return {"blocked": await threads.is_blocked(request_ip(request))}
