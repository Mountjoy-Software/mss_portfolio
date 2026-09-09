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

## Assistant

`claude-sonnet-5` answers chat, set in `backend/src/config.py`. The system prompt is
built once at import in `src/services/claude.py` so the cached prefix stays
byte-identical across requests. Retrieved context goes into the user turn, not the
system prompt. Follow-up suggestions come from `claude-haiku-4-5` on a separate call.

Portfolio content is embedded with Amazon Bedrock Titan and indexed in Qdrant, which
serves both retrieval for the assistant and the graph explorer.
