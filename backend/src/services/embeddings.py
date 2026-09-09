import asyncio
import json
from functools import cache

import boto3

from src.config import settings

_CONCURRENCY = 8


@cache
def _runtime():
    return boto3.client("bedrock-runtime", region_name=settings.AWS_REGION)


def _invoke(text: str) -> list[float]:
    response = _runtime().invoke_model(
        modelId=settings.EMBED_MODEL,
        contentType="application/json",
        accept="application/json",
        body=json.dumps(
            {
                "inputText": text,
                "dimensions": settings.EMBED_DIMENSIONS,
                "normalize": True,
            }
        ),
    )
    return json.loads(response["body"].read())["embedding"]


async def embed(text: str) -> list[float]:
    return await asyncio.to_thread(_invoke, text)


async def embed_all(texts: list[str]) -> list[list[float]]:
    gate = asyncio.Semaphore(_CONCURRENCY)

    async def one(text: str) -> list[float]:
        async with gate:
            return await asyncio.to_thread(_invoke, text)

    return await asyncio.gather(*(one(text) for text in texts))
