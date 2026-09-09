# mss_portfolio

Portfolio site for Mountjoy Software Solutions, live at https://mountjoy.io.
Flutter web on S3/CloudFront, FastAPI on ECS Fargate, CDK for infra, GitHub Actions
for deploys.

## Conventions

No comments and no docstrings. Names carry the meaning. Delete any comments you find
while editing. Prompt text the model reads at runtime (system prompts, tool
descriptions, JSON schema descriptions) is functional content, not commentary, so
that stays.

No `Co-Authored-By` trailers in commit messages.

Contact email is `ross.mountjoy.carr@pm.me`. Never use `ross@bysavi.com`, that
belongs to a different company.

## Layout

```
backend/    FastAPI. src/api/v1 for routes, src/api/mcp.py for the MCP endpoint, src/services for logic, src/content for profile data
frontend/   Flutter web. lib/core shared, lib/features per page, lib/theme
infra/      CDK app. app.py wires four stacks from stacks/
scripts/    push-image.sh builds and pushes the API image
```

`backend/src/content/profile.json` is the single source of truth for the resume. The
API serves it and the assistant's system prompt is built from it.

## Commands

```bash
cd backend  && .venv/bin/python -m src.main
cd frontend && flutter analyze && flutter test
cd frontend && flutter run -d chrome --dart-define=API_BASE=http://localhost:8000
cd infra    && npx aws-cdk diff --app ".venv/bin/python app.py"
```

Local AWS work needs `AWS_PROFILE=mss`. The CDK CLI needs Node 22, so source nvm
first: `. "$HOME/.nvm/nvm.sh"`.

## Stacks

| Stack | Contents | Notes |
|---|---|---|
| `MssPortfolioData` | DynamoDB, ECR, secrets | Termination protection, `RETAIN` policies |
| `MssPortfolioApi` | VPC, cluster, Fargate service, ALB | No NAT gateway |
| `MssPortfolioSite` | S3, CloudFront, certificate, DNS | Depends on Api |
| `MssPortfolioCicd` | OIDC provider, deploy role | Trust scoped to `main` |

Deploy order matters. `MssPortfolioData` creates the ECR repo, then the image has to be
pushed, then the rest can deploy because the task definition references that tag.

## Assistant

`claude-sonnet-5` answers chat, set in `backend/src/config.py`. The system prompt is
built once at import in `src/services/claude.py` so the cached prefix stays
byte-identical across requests. Retrieved context goes into the user turn, not the
system prompt. Follow-up suggestions come from `claude-haiku-4-5` on a separate call.

Portfolio content is embedded with Amazon Bedrock Titan and indexed in Qdrant, which
serves retrieval for the assistant, the graph explorer, and the MCP server.

`src/api/mcp.py` implements the Streamable HTTP transport by hand, unauthenticated, at
`/mcp`. CloudFront routes `/mcp*` to the API alongside `/api/*`. Retrieval caps results
per kind so a broad question does not come back as six near-identical skill points.

## Resume

`/synthesize-resume <who is this for>` and the assistant's `synthesize_resume` tool both
land in `src/services/resume.py`. It asks `claude-sonnet-5` for a structured selection
from the record, then renders one page with reportlab. Role ids, project slugs and skill
names that do not match `profile.json` are dropped in `_reconcile`, so the prose is the
model's and the facts are the record's.

The reader is whatever the visitor typed: a name, a role, a relationship, a pasted job
posting. The synthesis resolves that into `reader`, a short phrase addressed to the
person rather than an echo of the sentence, and the page, the footer and the filename
all use it. The URL keeps the original text, because that is the cache key and what a
re-render reads. Long input is truncated in `normalize`, never rejected.

`POST /api/v1/resume` synthesizes and caches, `GET /api/v1/resume.pdf?for=...` renders
and synthesizes on a miss. The cache is in process, so another task just synthesizes
again.

Structured output goes through `messages.parse`. Sonnet 5 thinks whether or not thinking
is asked for, and the thinking comes out of the same budget as the JSON: at 4000 tokens
the call returns `stop_reason` `max_tokens` and `parsed_output` `None`.

One page is a promise, so `_fit` measures the story and drops bullets, then projects,
then skills, until it fits. `KeepInFrame` is the last resort, and because shrinking
re-wraps at a wider width every table has to be `hAlign="LEFT"` or it drifts right.

JetBrains Mono and the logo live in `backend/src/assets`; the frontend gets the same
typeface from Google Fonts at runtime.

The download is a markdown link, so it must not reach `context.go` or the SPA router
swallows it. `streaming_markdown.dart` hands `/api/` and `/media/` hrefs to `launchUrl`
instead.
