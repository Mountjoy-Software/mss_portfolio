import asyncio
import json
import logging
import time
from typing import AsyncIterator

from boto3.dynamodb.conditions import Key

from src.config import settings
from src.services.dynamo import table

log = logging.getLogger(__name__)

BANNED = "Ross banned you. Sorry"

_REFRESH_SECONDS = 20.0
_blocked: frozenset[str] = frozenset()
_checked = 0.0
_lock = asyncio.Lock()


def _save(
    thread_id: str, ip: str, agent: str, messages: list[dict]
) -> None:
    now = int(time.time())
    table().update_item(
        Key={"pk": "thread", "sk": thread_id},
        UpdateExpression=(
            "SET #messages = :messages, #turns = :turns, #ip = :ip, "
            "#agent = :agent, #updated = :now, #expires = :ttl, "
            "#created = if_not_exists(#created, :now)"
        ),
        ExpressionAttributeNames={
            "#messages": "messages",
            "#turns": "turns",
            "#ip": "ip",
            "#agent": "agent",
            "#updated": "updated",
            "#created": "created",
            "#expires": "expires_at",
        },
        ExpressionAttributeValues={
            ":messages": messages,
            ":turns": len(messages),
            ":ip": ip,
            ":agent": agent[:300],
            ":now": now,
            ":ttl": now + settings.THREAD_TTL_DAYS * 86400,
        },
    )


def _token(frame: str) -> str:
    if not frame.startswith("data: "):
        return ""
    try:
        payload = json.loads(frame[6:])
    except json.JSONDecodeError:
        return ""
    if payload.get("event") not in ("token", "error"):
        return ""
    return payload.get("text") or payload.get("message") or ""


async def recording(
    stream: AsyncIterator[str],
    thread_id: str,
    ip: str,
    agent: str,
    history: list[dict],
) -> AsyncIterator[str]:
    spoken: list[str] = []
    try:
        async for frame in stream:
            spoken.append(_token(frame))
            yield frame
    finally:
        messages = [
            {"role": turn["role"], "content": turn["content"]} for turn in history
        ]
        messages.append({"role": "assistant", "content": "".join(spoken)})
        try:
            await asyncio.to_thread(_save, thread_id, ip, agent, messages)
        except Exception:
            log.exception("could not record thread %s", thread_id)


def _all_threads() -> list[dict]:
    found = table().query(
        KeyConditionExpression=Key("pk").eq("thread"),
        Limit=settings.THREAD_LIST_LIMIT,
    )
    return found.get("Items") or []


async def listing() -> list[dict]:
    items = await asyncio.to_thread(_all_threads)
    threads = [
        {
            "id": item.get("sk"),
            "ip": item.get("ip") or "unknown",
            "agent": item.get("agent") or "",
            "turns": int(item.get("turns") or 0),
            "created": int(item.get("created") or 0),
            "updated": int(item.get("updated") or 0),
            "messages": [
                {
                    "role": str(turn.get("role") or ""),
                    "content": str(turn.get("content") or ""),
                }
                for turn in item.get("messages") or []
            ],
        }
        for item in items
    ]
    threads.sort(key=lambda thread: thread["updated"], reverse=True)
    return threads


def _read_blocks() -> list[str]:
    found = table().query(KeyConditionExpression=Key("pk").eq("block"))
    return [str(item["sk"]) for item in found.get("Items") or []]


async def blocked_ips(force: bool = False) -> frozenset[str]:
    global _blocked, _checked
    if not force and time.monotonic() - _checked < _REFRESH_SECONDS:
        return _blocked
    async with _lock:
        if not force and time.monotonic() - _checked < _REFRESH_SECONDS:
            return _blocked
        try:
            _blocked = frozenset(await asyncio.to_thread(_read_blocks))
            _checked = time.monotonic()
        except Exception:
            log.exception("could not read the block list")
    return _blocked


async def is_blocked(ip: str) -> bool:
    return ip in await blocked_ips()


def _write_block(ip: str) -> None:
    table().put_item(Item={"pk": "block", "sk": ip, "created": int(time.time())})


def _delete_block(ip: str) -> None:
    table().delete_item(Key={"pk": "block", "sk": ip})


async def block(ip: str) -> None:
    await asyncio.to_thread(_write_block, ip)
    await blocked_ips(force=True)


async def unblock(ip: str) -> None:
    await asyncio.to_thread(_delete_block, ip)
    await blocked_ips(force=True)
