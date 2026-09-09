from fastapi import APIRouter, HTTPException, Request
from fastapi.responses import StreamingResponse

from src.config import settings
from src.schemas.chat import ChatRequest
from src.services import claude, dynamo, vectors

router = APIRouter()

TOO_FAST = "Too many questions for right now. Try again in a minute."
TOO_MUCH = (
    "That is a lot of questions for one visit. Try again later, or email "
    "ross.mountjoy.carr@pm.me and reach the real thing."
)


def _client_ip(request: Request) -> str:
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.client.host if request.client else "unknown"


@router.post("/chat")
async def chat(body: ChatRequest, request: Request) -> StreamingResponse:
    ip = _client_ip(request)

    if not await dynamo.within_rate_limit(
        "chat", ip, settings.CHAT_RATE_LIMIT, settings.CHAT_RATE_WINDOW_SECONDS
    ):
        raise HTTPException(429, TOO_FAST)

    if not await dynamo.within_rate_limit(
        "chat-hour", ip, settings.CHAT_HOURLY_LIMIT, 3600
    ):
        raise HTTPException(429, TOO_MUCH)

    history = [t.model_dump() for t in body.messages]
    retrieved = await vectors.context(
        history[-1]["content"], settings.RAG_CONTEXT_LIMIT
    )
    return StreamingResponse(
        claude.stream_reply(history, retrieved),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-store", "X-Accel-Buffering": "no"},
    )
