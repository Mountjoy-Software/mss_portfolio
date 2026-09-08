from fastapi import APIRouter, HTTPException, Request
from fastapi.responses import StreamingResponse

from src.schemas.chat import ChatRequest
from src.services import claude, dynamo

router = APIRouter()


def _client_ip(request: Request) -> str:
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.client.host if request.client else "unknown"


@router.post("/chat")
async def chat(body: ChatRequest, request: Request) -> StreamingResponse:
    if not await dynamo.within_rate_limit(_client_ip(request)):
        raise HTTPException(429, "Rate limit reached. Try again later.")

    history = [t.model_dump() for t in body.messages]
    return StreamingResponse(
        claude.stream_reply(history),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-store", "X-Accel-Buffering": "no"},
    )
