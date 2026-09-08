# mountjoy.io

Portfolio site for Mountjoy Software Solutions. The source is public because the
infrastructure is part of what it's meant to show.

## Stack

- **Frontend**: Flutter web, Riverpod, go_router
- **Backend**: FastAPI on Python 3.12
- **LLM**: Anthropic Claude (streaming, tool use, prompt caching)
- **Infra**: AWS CDK in Python
- **CI**: GitHub Actions with OIDC

## Infrastructure

```
mountjoy.io
    |
CloudFront
    |-- /*      -> S3 (private, OAC)     Flutter bundle
    |-- /api/*  -> ALB -> ECS Fargate    FastAPI
                             |
                          DynamoDB
```

One distribution serves both origins, so the browser is same-origin with the API and
there's no CORS involved. The load balancer's security group only accepts the CloudFront
origin-facing prefix list, so the API isn't reachable directly.

Four stacks:

| Stack | Contents |
|---|---|
| `MssPortfolioData` | DynamoDB table, ECR repo, secrets |
| `MssPortfolioApi` | VPC, ECS cluster, Fargate service, ALB |
| `MssPortfolioSite` | S3 bucket, CloudFront, certificate, DNS |
| `MssPortfolioCicd` | GitHub OIDC provider and deploy role |

## Layout

```
backend/    FastAPI service
frontend/   Flutter web client
infra/      CDK app
scripts/    build and push helpers
```

## Running locally

```bash
cd backend
python -m venv .venv
.venv/bin/pip install -r requirements.txt -r requirements-dev.txt
cp .env.example .env    # add your ANTHROPIC_API_KEY
.venv/bin/python -m src.main
```

```bash
cd frontend
flutter pub get
flutter run -d chrome --dart-define=API_BASE=http://localhost:8000
```

`API_BASE` is only for local work. In production the client reads `Uri.base.origin`.

## Deploying

Pushes to `main` build the image, deploy the stacks with the commit SHA as the image tag,
publish the web bundle and invalidate the cache.

By hand:

```bash
cd infra
npx aws-cdk deploy MssPortfolioData
../scripts/push-image.sh
npx aws-cdk deploy --all -c image_tag=<sha>
```

Data stack first, since the task definition points at an image that has to exist already.

## Notes

Things that took a while to work out, kept here so I don't repeat them.

**`addListener` opens the load balancer by default.** It adds `0.0.0.0/0` next to the
prefix list rule, which quietly cancels it out. Pass `open=False`.

**Point the CloudFront origin at the custom domain, not the ALB hostname.**
`LoadBalancerV2Origin` uses the load balancer's own DNS name, which won't match a
certificate issued for `api.mountjoy.io`, and the origin handshake fails with a 502. Use
`HttpOrigin(api_domain)`.

**Don't use CloudFront error pages for SPA routing.** They apply to the whole
distribution, so a 404 from the API comes back as `index.html` with a 200. There's a
viewer-request function on the static behaviour instead.

**Flutter doesn't hash `main.dart.js`.** A cached copy next to a fresh
`flutter_bootstrap.js` gives you a blank page, so everything is published with
`max-age=0, must-revalidate` and the cache is invalidated on deploy.

**boto3 can't read `aws login` credentials without `botocore[crt]`,** and it fails at
request time rather than import. That's what `requirements-dev.txt` is for. Fargate uses
the task role, so it isn't needed in the image.
