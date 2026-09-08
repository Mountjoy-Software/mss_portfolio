import asyncio
import hashlib
import time
from functools import cache

import boto3

from src.config import settings


@cache
def table():
    resource = boto3.resource(
        "dynamodb",
        region_name=settings.AWS_REGION,
        endpoint_url=settings.DDB_ENDPOINT or None,
    )
    return resource.Table(settings.DDB_TABLE)


def _visitor_key(ip: str) -> str:
    digest = hashlib.sha256(f"{settings.IP_HASH_SALT}{ip}".encode()).hexdigest()
    return digest[:32]


def _consume(ip: str) -> int:
    window = int(time.time()) // settings.CHAT_RATE_WINDOW_SECONDS
    updated = table().update_item(
        Key={"pk": f"rate#{_visitor_key(ip)}", "sk": str(window)},
        UpdateExpression="ADD hits :one SET expires_at = if_not_exists(expires_at, :ttl)",
        ExpressionAttributeValues={
            ":one": 1,
            ":ttl": (window + 2) * settings.CHAT_RATE_WINDOW_SECONDS,
        },
        ReturnValues="UPDATED_NEW",
    )
    return int(updated["Attributes"]["hits"])


async def within_rate_limit(ip: str) -> bool:
    hits = await asyncio.to_thread(_consume, ip)
    return hits <= settings.CHAT_RATE_LIMIT
