import asyncio
import json
import logging
from typing import AsyncIterator

from anthropic import APIConnectionError, APIStatusError, RateLimitError

from src.config import settings
from src.content import profile
from src.services import resume
from src.services.llm import client

log = logging.getLogger(__name__)

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
    },
    {
        "name": "synthesize_resume",
        "description": (
            "Synthesize a one-page PDF resume for Ross from his record, written for "
            "one particular reader, and get back a link the visitor can download. "
            "Call this whenever a visitor asks to download, view, generate or see "
            "his resume or CV. Never answer that kind of request with prose alone, "
            "and never ask who it is for before calling: infer the reader from the "
            "conversation, and where there is nothing to go on pass a general "
            "reader and invite them afterwards to name a specific one."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "audience": {
                    "type": "string",
                    "description": (
                        "Who the resume is for. A name where the visitor gave one "
                        "('Allison, his wife'), otherwise a role or a company "
                        "('a fintech CTO hiring a backend contractor'), or the "
                        "requirements where they pasted a posting. Use the "
                        "visitor's own words, and 'a hiring manager or prospective "
                        "client' where they gave nothing."
                    ),
                }
            },
            "required": ["audience"],
            "additionalProperties": False,
        },
        "strict": True,
    },
]


def _system_prompt() -> str:
    p = profile()
    projects = "\n".join(
        f"- {x['name']}, started {x['year']} "
        f"(slug {x['slug']}, write-up at /deck/{x['slug']}). {x['blurb']}"
        for x in sorted(p["projects"], key=lambda x: x["year"])
    )
    experience = "\n".join(
        f"- {e['role']} at "
        + (f"[{e['company']}]({e['url']})" if e.get("url") else e["company"])
        + f", {e['start']} to {e['end']}\n"
        + "\n".join(f"    - {h}" for h in e["highlights"])
        for e in p["experience"]
    )
    links = "\n".join(f"- [{name}]({url})" for name, url in p["links"].items())
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
write-up](/deck/dashmachine))`. At most once per project in a reply; later
mentions of the same project are plain text.

Employers below are written as markdown links where the company has a URL. Copy
that link the first time you name the company in a reply, exactly as written.
Again, only the first mention. Never paste a bare URL into an answer; a bare URL
does not render as a link.

The retrieved excerpts also carry Repository, Live, Deck and Images lines where a
project has them. Link a repository or a live site inline, and embed a screenshot
with `![caption](/media/...)` when a picture makes the point better than a
sentence. Never invent a path; only use one that appears in this prompt or in the
excerpts. One or two images is plenty.

# Contact
Based in {p['location']}. These are written as markdown already, so copy them
verbatim when a visitor asks how to reach him or where his code is:
- [{p['email']}](mailto:{p['email']})
{links}

# Summary
{p['summary']}

# Skills
{json.dumps(p['skills'], indent=2, sort_keys=True)}

# Experience
Most recent first. Where the same employer appears twice it is one continuous
relationship that changed arrangement, not two separate jobs, so describe it that
way. Say "full-time employee" and "independent contractor"; never "W2" or "1099".
Dates are written YYYY-MM here; write them out in prose, so "September 2022".

{experience}

# Projects
Oldest first.

{projects}"""


def _follow_up_system() -> str:
    p = profile()
    projects = ", ".join(x["name"] for x in p["projects"])
    companies = ", ".join(e["company"] for e in p["experience"])
    return f"""A visitor to {p['name']}'s consulting portfolio just asked a question.
Write the one question they are most likely to want to ask next.

The site can answer questions about his roles ({companies}), his projects
({projects}), his skills across AWS infrastructure, Python, FastAPI, Flutter,
LLM integration and vector search, where he is based, and how to hire him. Stay
inside that ground, and move to a different angle than the one just asked rather
than rephrasing it.

Write it in the visitor's voice, about Ross in the third person, at most 60
characters. Output the question alone, with no quotes and nothing else."""


SYSTEM_PROMPT = _system_prompt()
FOLLOW_UP_SYSTEM = _follow_up_system()


async def _follow_up(question: str) -> str | None:
    try:
        reply = await client().messages.create(
            model=settings.SUGGEST_MODEL,
            max_tokens=64,
            system=FOLLOW_UP_SYSTEM,
            messages=[{"role": "user", "content": question}],
        )
    except Exception:
        log.warning("follow-up suggestion failed", exc_info=True)
        return None
    text = "".join(
        block.text for block in reply.content if block.type == "text"
    ).strip()
    text = text.splitlines()[0].strip().strip('"') if text else ""
    return text if 0 < len(text) <= 100 else None


def _project_detail(slug: str) -> str:
    for x in profile()["projects"]:
        if x["slug"] == slug:
            return x.get("details") or x["blurb"]
    known = ", ".join(x["slug"] for x in profile()["projects"])
    return f"No project with slug {slug!r}. Known slugs: {known}"


async def _synthesize_resume(audience: str) -> str:
    audience = resume.normalize(audience)
    try:
        synth = await resume.for_audience(audience)
    except Exception:
        log.exception("resume synthesis failed")
        return (
            "The resume could not be synthesized. Tell the visitor to try again "
            "shortly, or to email for one."
        )
    return f"""A one-page PDF is ready, written for {synth.reader}.

Headline: {synth.headline}
Opening: {synth.positioning}
Download path: {resume.download_path(audience)}

Say in one or two sentences who it is aimed at, calling them {synth.reader}, and what
it leads with. Then offer the download as a markdown link with the path exactly as
written above, like [Download the PDF]({resume.download_path(audience)}). Never paste
the path as bare text. Mention that it was synthesized just now and that a different
reader gets a different resume."""


async def _run_tool(name: str, args: dict) -> str:
    if name == "get_project_detail":
        return _project_detail(args.get("slug"))
    if name == "synthesize_resume":
        return await _synthesize_resume(args.get("audience") or "a hiring manager")
    return f"No such tool: {name}"


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
    asked = history[-1].get("content") if history else None
    suggestion = (
        asyncio.create_task(_follow_up(asked)) if isinstance(asked, str) else None
    )
    try:
        async for frame in _stream_turns(
            _with_context(history, retrieved or []), suggestion
        ):
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
    finally:
        if suggestion is not None and not suggestion.done():
            suggestion.cancel()


async def _stream_turns(
    history: list[dict], suggestion: asyncio.Task | None
) -> AsyncIterator[str]:
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
                suggest=await suggestion if suggestion is not None else None,
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
                        "content": await _run_tool(block.name, block.input),
                    }
                )

        messages.append({"role": "assistant", "content": reply.content})
        messages.append({"role": "user", "content": results})
