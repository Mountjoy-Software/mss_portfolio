from functools import cache

from anthropic import AsyncAnthropic

from src.config import settings


@cache
def client() -> AsyncAnthropic:
    return AsyncAnthropic(api_key=settings.ANTHROPIC_API_KEY)
