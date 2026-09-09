import json

from fastapi import Request

from src.config import settings
from src.services.dynamo import within_rate_limit
from src.services.threads import BANNED, is_blocked

BLOCKED_SUFFIXES = (
    ".php",
    ".asp",
    ".aspx",
    ".jsp",
    ".cgi",
    ".env",
    ".sql",
    ".bak",
    ".old",
    ".ini",
    ".yml",
    ".yaml",
)

BLOCKED_SEGMENTS = (
    "wp-admin",
    "wp-content",
    "wp-includes",
    "wp-login",
    "phpmyadmin",
    ".git",
    ".aws",
    ".ssh",
    "actuator",
    "solr",
    "vendor",
    "cgi-bin",
    "hudson",
    "jenkins",
)


def client_ip(headers: dict[bytes, bytes] | None, fallback: str) -> str:
    found = headers or {}
    stamped = found.get(b"x-viewer-ip")
    if stamped:
        return stamped.decode(errors="replace").strip()
    forwarded = found.get(b"x-forwarded-for")
    if forwarded:
        return forwarded.decode(errors="replace").split(",")[0].strip()
    return fallback


def request_ip(request: Request) -> str:
    stamped = request.headers.get("x-viewer-ip")
    if stamped:
        return stamped.strip()
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.client.host if request.client else "unknown"


def looks_hostile(path: str) -> bool:
    lowered = path.lower()
    if lowered.endswith(BLOCKED_SUFFIXES):
        return True
    return any(segment in lowered for segment in BLOCKED_SEGMENTS)


class Guard:
    def __init__(self, app):
        self.app = app
        self._health = f"{settings.API_V1_STR}/health"
        self._unbannable = (
            f"{settings.API_V1_STR}/admin",
            f"{settings.API_V1_STR}/visitor",
        )

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http":
            return await self.app(scope, receive, send)

        path = scope.get("path", "")
        if path == self._health:
            return await self.app(scope, receive, send)

        if looks_hostile(path):
            return await _reject(send, 404, "Not found.")

        headers = dict(scope.get("headers") or [])

        declared = headers.get(b"content-length")
        if declared and declared.isdigit():
            if int(declared) > settings.MAX_BODY_BYTES:
                return await _reject(send, 413, "That request is too large.")

        peer = scope.get("client")
        ip = client_ip(headers, peer[0] if peer else "unknown")

        allowed = await within_rate_limit(
            "api", ip, settings.API_RATE_LIMIT, settings.API_RATE_WINDOW_SECONDS
        )
        if not allowed:
            return await _reject(
                send, 429, "That is a lot of requests. Give it a minute."
            )

        if not path.startswith(self._unbannable) and await is_blocked(ip):
            return await _reject(send, 403, BANNED)

        await self.app(scope, receive, send)


async def _reject(send, status: int, message: str) -> None:
    body = json.dumps({"detail": message}).encode()
    await send(
        {
            "type": "http.response.start",
            "status": status,
            "headers": [
                (b"content-type", b"application/json"),
                (b"content-length", str(len(body)).encode()),
                (b"cache-control", b"no-store"),
            ],
        }
    )
    await send({"type": "http.response.body", "body": body})
