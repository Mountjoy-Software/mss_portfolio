import logging

from fastapi import APIRouter, HTTPException, Query, Request, Response

from src.config import settings
from src.content import profile
from src.schemas.resume import ResumeRequest
from src.security import request_ip
from src.services import dynamo, resume

log = logging.getLogger(__name__)

router = APIRouter()

TOO_MANY = (
    "That is a lot of resumes for one visit. Try again later, or email "
    f"{profile()['email']} and ask for one."
)
UNAVAILABLE = "The resume could not be synthesized right now. Try again shortly."

Audience = Query(alias="for", min_length=2, max_length=4000)


async def _allow(request: Request) -> None:
    allowed = await dynamo.within_rate_limit(
        "resume",
        request_ip(request),
        settings.RESUME_RATE_LIMIT,
        settings.RESUME_RATE_WINDOW_SECONDS,
    )
    if not allowed:
        raise HTTPException(429, TOO_MANY)


@router.post("/resume")
async def synthesize(body: ResumeRequest, request: Request) -> dict:
    await _allow(request)
    audience = resume.normalize(body.audience)
    try:
        synth = await resume.for_audience(audience)
    except Exception:
        log.exception("resume synthesis failed")
        raise HTTPException(503, UNAVAILABLE)
    return {
        "reader": synth.reader,
        "headline": synth.headline,
        "positioning": synth.positioning,
        "url": resume.download_path(audience),
    }


@router.get("/resume.pdf")
async def download(request: Request, audience: str = Audience) -> Response:
    await _allow(request)
    audience = resume.normalize(audience)
    try:
        synth = await resume.for_audience(audience)
        content = resume.render(synth)
    except Exception:
        log.exception("resume render failed")
        raise HTTPException(503, UNAVAILABLE)
    disposition = f'attachment; filename="{resume.filename(synth.reader)}"'
    return Response(
        content,
        media_type="application/pdf",
        headers={"content-disposition": disposition, "cache-control": "no-store"},
    )
