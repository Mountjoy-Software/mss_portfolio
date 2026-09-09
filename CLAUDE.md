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
backend/    FastAPI. src/api/v1 for routes, src/services for logic, src/content for profile data
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

## Gotchas

`elbv2.addListener` defaults to `open=True` and adds `0.0.0.0/0` alongside the
CloudFront prefix list rule, defeating it. Keep `open=False`. Verify by confirming a
request to `https://api.mountjoy.io/api/v1/health` times out while the same path
through `https://mountjoy.io` returns 200.

The CloudFront API origin must be `api.mountjoy.io`, not the ALB's own hostname.
`LoadBalancerV2Origin` uses the latter and the origin TLS handshake then fails against
a certificate issued for the custom domain, giving a 502.

Never add CloudFront custom error responses for SPA routing. They are
distribution-wide and would turn API 404s into `index.html` with a 200. The
`SPA_ROUTER` CloudFront Function on the static behaviour handles deep links.

Flutter web does not content-hash `main.dart.js`. Publish everything with
`max-age=0, must-revalidate` and invalidate on deploy.

GitHub issues immutable-identifier OIDC subs on this account, so the claim looks like
`repo:Mountjoy-Software@326559192/mss_portfolio@1361615689:ref:refs/heads/main`, not the
documented `repo:owner/name:ref:...`. The scoping in `stacks/cicd.py` therefore comes
from exact `repository` and `ref` conditions, with a wildcard `sub` alongside them
because IAM refuses a GitHub OIDC trust policy that does not constrain `sub` or
`job_workflow_ref`. To see the real claims, fetch a token in a workflow step with
`ACTIONS_ID_TOKEN_REQUEST_URL` and decode the payload.

boto3 cannot read `aws login` credentials without `botocore[crt]` and fails at request
time, not import. It lives in `requirements-dev.txt` only; Fargate uses the task role.

`scripts/dev.sh` exports short-lived AWS credentials into the api container for Bedrock,
and they expire. A long-running compose session eventually fails embedding calls with
`ExpiredTokenException`; `./scripts/dev.sh up -d --force-recreate api` refreshes them.
`dev.sh restart api` does not, because `docker compose restart` keeps the container's
original environment.
Retrieval and the index build both degrade rather than fail when that happens, so the
symptom is a graph 503 and answers without retrieved context, not an outage.

`ChatTurn` is mutable and the same instance is shared across successive `ChatState`
values, because streaming appends to `pending.content` in place. `ref.listen`'s
`previous` and `next` therefore read the same object, so diffing them for new tokens
always compares equal. `terminal_page.dart` caches turn count and tail length in the
State and diffs against those instead.

`StreamingMarkdown` must keep the same widget tree shape whether or not it is
streaming. Returning the bare `MarkdownBody` when the stream ends, instead of leaving
it wrapped, changes the widget type at that position, so Flutter unmounts the whole
subtree and rebuilds it. Images reload through their `loadingBuilder` placeholder, the
entry's height changes, and the transcript appears to jump to a random place. The
`ShaderMask` stays put and its gradient goes opaque instead.

## Anthropic API

Model is `claude-sonnet-5`, set in `backend/src/config.py`. The system prompt is built
once at import in `src/services/claude.py` so the cached prefix stays byte-identical
across requests. Changing how that string is assembled per-request kills the cache.
Check `cache_read` in the `done` SSE frame to confirm it still hits.
