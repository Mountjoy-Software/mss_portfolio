import base64
import binascii
import hashlib
import hmac
import json
import secrets
import time

from src.config import settings

_SCHEME = "scrypt"
_SEP = ":"
_MAXMEM = 64 * 1024 * 1024


def configured() -> bool:
    return bool(
        settings.ADMIN_USERNAME
        and settings.ADMIN_PASSWORD_HASH
        and settings.ADMIN_SESSION_SECRET
    )


def _encode(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode()


def _decode(value: str) -> bytes:
    return base64.urlsafe_b64decode(_pad(value.encode()))


def hash_password(password: str, n: int = 2**14, r: int = 8, p: int = 1) -> str:
    salt = secrets.token_bytes(16)
    digest = hashlib.scrypt(
        password.encode(), salt=salt, n=n, r=r, p=p, dklen=32, maxmem=_MAXMEM
    )
    return _SEP.join(
        [
            _SCHEME,
            str(n),
            str(r),
            str(p),
            _encode(salt),
            _encode(digest),
        ]
    )


def verify_password(password: str, encoded: str) -> bool:
    try:
        scheme, n, r, p, salt, digest = encoded.split(_SEP)
        if scheme != _SCHEME:
            return False
        expected = _decode(salt), _decode(digest)
        actual = hashlib.scrypt(
            password.encode(),
            salt=expected[0],
            n=int(n),
            r=int(r),
            p=int(p),
            dklen=len(expected[1]),
            maxmem=_MAXMEM,
        )
    except (ValueError, TypeError, binascii.Error):
        return False
    return hmac.compare_digest(actual, expected[1])


def _pad(value: bytes) -> bytes:
    return value + b"=" * (-len(value) % 4)


def _sign(body: bytes) -> bytes:
    return hmac.new(
        settings.ADMIN_SESSION_SECRET.encode(), body, hashlib.sha256
    ).digest()


def issue_token() -> str:
    payload = {
        "sub": settings.ADMIN_USERNAME,
        "exp": int(time.time()) + settings.ADMIN_SESSION_HOURS * 3600,
    }
    raw = json.dumps(payload, separators=(",", ":"), sort_keys=True).encode()
    body = base64.urlsafe_b64encode(raw).rstrip(b"=")
    signature = base64.urlsafe_b64encode(_sign(body)).rstrip(b"=")
    return f"{body.decode()}.{signature.decode()}"


def valid_token(token: str) -> bool:
    if not configured():
        return False
    try:
        body, signature = token.encode().split(b".")
        if not hmac.compare_digest(
            base64.urlsafe_b64decode(_pad(signature)), _sign(body)
        ):
            return False
        payload = json.loads(base64.urlsafe_b64decode(_pad(body)))
    except Exception:
        return False
    return payload.get("sub") == settings.ADMIN_USERNAME and (
        int(payload.get("exp") or 0) > time.time()
    )
