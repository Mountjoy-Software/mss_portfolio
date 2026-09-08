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


def _consume(bucket: str, ip: str, window_seconds: int) -> int:
    window = int(time.time()) // window_seconds
    updated = table().update_item(
        Key={"pk": f"rate#{bucket}#{_visitor_key(ip)}", "sk": str(window)},
        UpdateExpression="ADD hits :one SET expires_at = if_not_exists(expires_at, :ttl)",
        ExpressionAttributeValues={
            ":one": 1,
            ":ttl": (window + 2) * window_seconds,
        },
        ReturnValues="UPDATED_NEW",
    )
    return int(updated["Attributes"]["hits"])


async def within_rate_limit(
    bucket: str, ip: str, limit: int, window_seconds: int
) -> bool:
    try:
        hits = await asyncio.to_thread(_consume, bucket, ip, window_seconds)
    except Exception:
        return True
    return hits <= limit
