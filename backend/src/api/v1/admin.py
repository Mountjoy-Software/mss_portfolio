import asyncio
import ipaddress

from fastapi import APIRouter, Header, HTTPException, Request

from src.config import settings
from src.schemas.admin import Credentials, Target
from src.security import request_ip
from src.services import admin, dynamo, threads

router = APIRouter(prefix="/admin")

UNAUTHORISED = "Sign in first."


def _require_session(authorization: str | None) -> None:
    if not admin.configured():
        raise HTTPException(503, "The admin console is not configured.")
    scheme, _, token = (authorization or "").partition(" ")
    if scheme.lower() != "bearer" or not admin.valid_token(token):
        raise HTTPException(401, UNAUTHORISED)


def _clean(ip: str) -> str:
    try:
        return str(ipaddress.ip_address(ip.strip()))
    except ValueError:
        raise HTTPException(422, "That is not an IP address.")


@router.post("/login")
async def login(body: Credentials, request: Request) -> dict:
    if not admin.configured():
        raise HTTPException(503, "The admin console is not configured.")

    ip = request_ip(request)
    if not await dynamo.within_rate_limit(
        "admin-login",
        ip,
        settings.ADMIN_LOGIN_LIMIT,
        settings.ADMIN_LOGIN_WINDOW_SECONDS,
    ):
        raise HTTPException(429, "Too many attempts. Wait a few minutes.")

    correct = await asyncio.to_thread(
        admin.verify_password, body.password, settings.ADMIN_PASSWORD_HASH
    )
    if body.username != settings.ADMIN_USERNAME or not correct:
        raise HTTPException(401, "Wrong username or password.")

    return {"token": admin.issue_token(), "hours": settings.ADMIN_SESSION_HOURS}


@router.get("/threads")
async def all_threads(authorization: str | None = Header(default=None)) -> dict:
    _require_session(authorization)
    return {
        "threads": await threads.listing(),
        "blocked": sorted(await threads.blocked_ips(force=True)),
    }


@router.post("/block")
async def block(
    body: Target, authorization: str | None = Header(default=None)
) -> dict:
    _require_session(authorization)
    await threads.block(_clean(body.ip))
    return {"blocked": sorted(await threads.blocked_ips(force=True))}


@router.post("/unblock")
async def unblock(
    body: Target, authorization: str | None = Header(default=None)
) -> dict:
    _require_session(authorization)
    await threads.unblock(_clean(body.ip))
    return {"blocked": sorted(await threads.blocked_ips(force=True))}
