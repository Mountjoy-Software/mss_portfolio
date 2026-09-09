import json
import logging
from typing import AsyncIterator

from anthropic import (
    APIConnectionError,
    APIStatusError,
    AsyncAnthropic,
    RateLimitError,
)

from src.config import settings
from src.content import profile

log = logging.getLogger(__name__)

_client: AsyncAnthropic | None = None

TOOLS = [
    {
        "name": "get_project_detail",
        "description": (
            "Retrieve the long-form write-up for one of Ross's projects. The system "
            "prompt carries only a one-line blurb per project; call this when the "
            "visitor wants depth on a specific one."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "slug": {
                    "type": "string",
                    "description": "Project slug, as listed in the system prompt.",
                }
            },
            "required": ["slug"],
            "additionalProperties": False,
        },
        "strict": True,
    }
]


def _system_prompt() -> str:
    p = profile()
    projects = "\n".join(
        f"- {x['name']} (slug {x['slug']}, write-up at /deck/{x['slug']}). "
        f"{x['blurb']}"
        for x in p["projects"]
    )
    experience = "\n".join(
        f"- {e['role']} at {e['company']} ({e['start']} to {e['end']})\n"
        + "\n".join(f"    - {h}" for h in e["highlights"])
        for e in p["experience"]
    )
    return f"""You are the assistant on {p['name']}'s consulting portfolio, {p['business']}.
You answer visitors' questions about his experience, his projects, and whether he
is a fit for work they have in mind. Visitors are often hiring managers or
prospective clients.

Ground every claim in the record below. Never invent an employer, a date, a metric
or a technology. If the record does not cover what was asked, say so and suggest
emailing {p['email']}. Call get_project_detail when a visitor wants more than the
one-line blurb.

Keep answers short and concrete. Two or three sentences for a simple question, a
short list when comparing things. Write about Ross in the third person. Prefer a
specific detail over an adjective, and do not oversell.

Every project listed below has a full write-up. The first time you name one in a
reply, follow the name with its link, like `DashMachine ([open full
write-up](/deck/dashmachine))`. Do it once per project per reply, not on every
mention.

The retrieved excerpts also carry Repository, Live, Deck and Images lines where a
project has them. Link a repository or a live site inline, and embed a screenshot
with `![caption](/media/...)` when a picture makes the point better than a
sentence. Never invent a path; only use one that appears in this prompt or in the
excerpts. One or two images is plenty.

# Summary
{p['summary']}

# Skills
{json.dumps(p['skills'], indent=2, sort_keys=True)}

# Experience
{experience}

# Projects
{projects}"""


SYSTEM_PROMPT = _system_prompt()


def client() -> AsyncAnthropic:
    global _client
    if _client is None:
        _client = AsyncAnthropic(api_key=settings.ANTHROPIC_API_KEY)
    return _client


def _run_tool(name: str, args: dict) -> str:
    if name != "get_project_detail":
        return f"No such tool: {name}"
    slug = args.get("slug")
    for x in profile()["projects"]:
        if x["slug"] == slug:
            return x.get("details") or x["blurb"]
    known = ", ".join(x["slug"] for x in profile()["projects"])
    return f"No project with slug {slug!r}. Known slugs: {known}"


def _sse(event: str, **data) -> str:
    return f"data: {json.dumps({'event': event, **data})}\n\n"


def _with_context(history: list[dict], retrieved: list[dict]) -> list[dict]:
    if not retrieved or not history:
        return history
    excerpts = "\n\n".join(
        f"[{doc['kind']}] {doc['title']}\n{doc['text']}" for doc in retrieved
    )
    messages = list(history)
    last = dict(messages[-1])
    if last.get("role") != "user":
        return history
    messages[-1] = {
        "role": "user",
        "content": [
            {
                "type": "text",
                "text": (
                    "Excerpts retrieved from Ross's record by vector search, "
                    "most relevant first. Use them where they help and ignore "
                    "them where they do not.\n\n" + excerpts
                ),
            },
            {"type": "text", "text": last["content"]},
        ],
    }
    return messages


async def stream_reply(
    history: list[dict], retrieved: list[dict] | None = None
) -> AsyncIterator[str]:
    try:
        async for frame in _stream_turns(_with_context(history, retrieved or [])):
            yield frame
    except RateLimitError:
        log.warning("anthropic rate limited the chat request")
        yield _sse("error", message="The assistant is busy. Try again shortly.")
    except (APIStatusError, APIConnectionError):
        log.exception("anthropic request failed")
        yield _sse("error", message="The assistant is unavailable right now.")
    except Exception:
        log.exception("chat stream failed")
        yield _sse("error", message="Something went wrong answering that.")


async def _stream_turns(history: list[dict]) -> AsyncIterator[str]:
    messages = list(history)

    while True:
        async with client().messages.stream(
            model=settings.CHAT_MODEL,
            max_tokens=settings.CHAT_MAX_TOKENS,
            system=[
                {
                    "type": "text",
                    "text": SYSTEM_PROMPT,
                    "cache_control": {"type": "ephemeral", "ttl": "1h"},
                }
            ],
            thinking={"type": "adaptive"},
            output_config={"effort": "low"},
            tools=TOOLS,
            messages=messages,
        ) as stream:
            async for text in stream.text_stream:
                yield _sse("token", text=text)
            reply = await stream.get_final_message()

        if reply.stop_reason == "refusal":
            yield _sse("error", message="That request was declined.")
            return

        if reply.stop_reason != "tool_use":
            usage = reply.usage
            yield _sse(
                "done",
                model=reply.model,
                cache_read=usage.cache_read_input_tokens or 0,
                input_tokens=usage.input_tokens,
                output_tokens=usage.output_tokens,
            )
            return

        results = []
        for block in reply.content:
            if block.type == "tool_use":
                yield _sse("tool", name=block.name, input=block.input)
                results.append(
                    {
                        "type": "tool_result",
                        "tool_use_id": block.id,
                        "content": _run_tool(block.name, block.input),
                    }
                )

        messages.append({"role": "assistant", "content": reply.content})
        messages.append({"role": "user", "content": results})
