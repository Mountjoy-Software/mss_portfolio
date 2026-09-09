import base64
import binascii
import json
import logging
from typing import Any

from fastapi import APIRouter, Request, Response

from src.config import settings
from src.services import vectors

log = logging.getLogger(__name__)

router = APIRouter()

LATEST = "2026-07-28"
SUPPORTED = ("2026-07-28", "2025-11-25", "2025-06-18", "2025-03-26")
ASSUMED = "2025-03-26"

PARSE_ERROR = -32700
INVALID_REQUEST = -32600
METHOD_NOT_FOUND = -32601
INVALID_PARAMS = -32602
INTERNAL_ERROR = -32603
HEADER_MISMATCH = -32020
UNSUPPORTED_VERSION = -32021

TOOL = {
    "name": "search_ross_mountjoy",
    "title": "Ross Mountjoy background search",
    "description": (
        "Look up information about Ross Mountjoy and his software consulting "
        "business, Mountjoy Software Solutions. Covers his work history and "
        "roles, the projects he has built, the languages, frameworks and AWS "
        "services he works with, where he is based, and how to contact him. "
        "The query is embedded and matched by meaning against a vector index "
        "of his record, so ask it the way you would ask a person: 'what has "
        "he done with ECS', 'has he led an engineering team', 'what does he "
        "know about vector databases'. Returns the passages that matched, "
        "each with the repository, live URL, write-up and image links where "
        "the record has them."
    ),
    "inputSchema": {
        "type": "object",
        "properties": {
            "query": {
                "type": "string",
                "description": (
                    "What you want to know about Ross, in plain language."
                ),
                "minLength": 2,
                "maxLength": 500,
            },
            "limit": {
                "type": "integer",
                "description": "How many passages to return. Defaults to 6.",
                "minimum": 1,
                "maximum": 20,
            },
        },
        "required": ["query"],
        "additionalProperties": False,
    },
    "outputSchema": {
        "type": "object",
        "properties": {
            "results": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "kind": {"type": "string"},
                        "title": {"type": "string"},
                        "text": {"type": "string"},
                        "score": {"type": "number"},
                    },
                    "required": ["kind", "title", "text", "score"],
                    "additionalProperties": False,
                },
            }
        },
        "required": ["results"],
        "additionalProperties": False,
    },
}

NAMED = {"tools/call": "name", "resources/read": "uri", "prompts/get": "uri"}


class Failure(Exception):
    def __init__(self, status: int, code: int, message: str, **data):
        self.status = status
        self.code = code
        self.message = message
        self.data = data or None


def _decoded(value: str) -> str:
    if not (value.startswith("=?base64?") and value.endswith("?=")):
        return value
    try:
        raw = base64.b64decode(value[9:-2], validate=True)
        return raw.decode()
    except (binascii.Error, UnicodeDecodeError, ValueError):
        raise Failure(
            400, HEADER_MISMATCH, f"Header value {value!r} is not valid base64."
        )


def _allowed_origin(origin: str) -> bool:
    return origin in settings.CORS_ORIGINS or origin in settings.MCP_ORIGINS


def _version(request: Request, message: dict) -> str:
    meta = (message.get("params") or {}).get("_meta") or {}
    declared = meta.get("io.modelcontextprotocol/protocolVersion")
    header = request.headers.get("mcp-protocol-version")

    if header and declared and header != declared:
        raise Failure(
            400,
            HEADER_MISMATCH,
            "MCP-Protocol-Version header does not match the protocolVersion "
            "in _meta.",
        )

    asked = header or declared
    if asked is None and message.get("method") == "initialize":
        asked = (message.get("params") or {}).get("protocolVersion")
    if asked is None:
        return ASSUMED
    if asked not in SUPPORTED:
        raise Failure(
            400,
            UNSUPPORTED_VERSION,
            f"Protocol version {asked} is not supported.",
            supported=list(SUPPORTED),
        )
    return asked


def _check_headers(request: Request, message: dict) -> None:
    method = message.get("method")
    declared = request.headers.get("mcp-method")
    if declared and declared != method:
        raise Failure(
            400,
            HEADER_MISMATCH,
            f"Mcp-Method header {declared!r} does not match body method "
            f"{method!r}.",
        )

    field = NAMED.get(method or "")
    if field is None:
        return
    named = request.headers.get("mcp-name")
    if named is None:
        return
    expected = (message.get("params") or {}).get(field)
    if _decoded(named) != expected:
        raise Failure(
            400,
            HEADER_MISMATCH,
            f"Mcp-Name header {named!r} does not match body {field} "
            f"{expected!r}.",
        )


async def _call_tool(params: dict) -> dict:
    if params.get("name") != TOOL["name"]:
        raise Failure(
            400, INVALID_PARAMS, f"Unknown tool: {params.get('name')!r}"
        )

    arguments = params.get("arguments") or {}
    query = arguments.get("query")
    if not isinstance(query, str) or not query.strip():
        return {
            "content": [
                {
                    "type": "text",
                    "text": "Pass a query describing what you want to know.",
                }
            ],
            "isError": True,
        }

    limit = arguments.get("limit")
    if not isinstance(limit, int) or isinstance(limit, bool):
        limit = settings.RAG_CONTEXT_LIMIT
    limit = max(1, min(20, limit))

    found = await vectors.context(query.strip()[:500], limit)
    if not found:
        return {
            "content": [
                {
                    "type": "text",
                    "text": (
                        "Nothing in Ross's record matched that. The index may "
                        "also be rebuilding; try again shortly, or email "
                        f"{settings.CONTACT_EMAIL}."
                    ),
                }
            ],
            "structuredContent": {"results": []},
        }

    results = [
        {
            "kind": str(item.get("kind") or "unknown"),
            "title": str(item.get("title") or ""),
            "text": str(item.get("text") or ""),
            "score": float(item.get("score") or 0.0),
        }
        for item in found
    ]
    rendered = "\n\n".join(
        f"## {item['title']} ({item['kind']}, cosine "
        f"{item['score']:.3f})\n{item['text']}"
        for item in results
    )
    return {
        "content": [{"type": "text", "text": rendered}],
        "structuredContent": {"results": results},
        "isError": False,
    }


async def _dispatch(method: str, params: dict, version: str) -> dict:
    if method == "initialize":
        return {
            "protocolVersion": version,
            "capabilities": {"tools": {"listChanged": False}},
            "serverInfo": {
                "name": "mountjoy-software",
                "title": settings.PROJECT_NAME,
                "version": settings.APP_VERSION,
            },
            "instructions": (
                "One tool, search_ross_mountjoy, answers questions about Ross "
                "Mountjoy's background from a vector index of his portfolio."
            ),
        }
    if method == "ping":
        return {}
    if method == "tools/list":
        return {"tools": [TOOL]}
    if method == "tools/call":
        return await _call_tool(params)
    raise Failure(404, METHOD_NOT_FOUND, f"Method not found: {method}")


def _error(status: int, code: int, message: str, data, id_: Any) -> Response:
    error: dict[str, Any] = {"code": code, "message": message}
    if data:
        error["data"] = data
    return Response(
        content=json.dumps({"jsonrpc": "2.0", "id": id_, "error": error}),
        status_code=status,
        media_type="application/json",
        headers={"cache-control": "no-store"},
    )


@router.post("/mcp")
async def endpoint(request: Request) -> Response:
    origin = request.headers.get("origin")
    if origin and not _allowed_origin(origin):
        return _error(403, INVALID_REQUEST, "Origin is not allowed.", None, None)

    raw = await request.body()
    try:
        message = json.loads(raw)
    except (json.JSONDecodeError, UnicodeDecodeError):
        return _error(400, PARSE_ERROR, "Body is not valid JSON.", None, None)

    if not isinstance(message, dict):
        return _error(
            400,
            INVALID_REQUEST,
            "Body must be a single JSON-RPC request or notification.",
            None,
            None,
        )

    id_ = message.get("id")
    method = message.get("method")
    if not isinstance(method, str):
        return _error(400, INVALID_REQUEST, "Body has no method.", None, id_)

    try:
        version = _version(request, message)
        _check_headers(request, message)
    except Failure as failure:
        return _error(
            failure.status, failure.code, failure.message, failure.data, id_
        )

    if id_ is None:
        if method.startswith("notifications/"):
            return Response(status_code=202)
        return _error(
            400, INVALID_REQUEST, f"{method} is a request, not a notification.", None, None
        )

    try:
        result = await _dispatch(method, message.get("params") or {}, version)
    except Failure as failure:
        return _error(
            failure.status, failure.code, failure.message, failure.data, id_
        )
    except Exception:
        log.exception("mcp %s failed", method)
        return _error(500, INTERNAL_ERROR, "The server failed to answer.", None, id_)

    if version >= LATEST:
        result = {"resultType": "complete", **result}

    return Response(
        content=json.dumps({"jsonrpc": "2.0", "id": id_, "result": result}),
        media_type="application/json",
        headers={"cache-control": "no-store"},
    )


@router.api_route("/mcp", methods=["GET", "DELETE"])
async def rejected() -> Response:
    return Response(
        content=json.dumps({"detail": "POST JSON-RPC to this endpoint."}),
        status_code=405,
        media_type="application/json",
        headers={"allow": "POST", "cache-control": "no-store"},
    )
