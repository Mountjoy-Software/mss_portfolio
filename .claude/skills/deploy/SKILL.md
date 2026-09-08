---
name: deploy
description: Deploy this project to AWS by hand, in the right order, and verify it afterwards. Use when asked to deploy, ship, redeploy, roll back, or push infrastructure changes for mss_portfolio, or when a deploy has failed and needs diagnosing.
---

# Deploying mss_portfolio

Normally `main` deploys itself through `.github/workflows/deploy.yml`. Deploy by hand
when the pipeline is broken, when testing an infra change before committing, or when
rolling back.

## Setup

```bash
. "$HOME/.nvm/nvm.sh"
export AWS_PROFILE=mss AWS_REGION=us-east-1
cd infra
```

The CDK CLI needs Node 22 and every invocation needs `--app ".venv/bin/python app.py"`
unless the venv is active.

## Order

The Fargate task definition references an image tag that must already be in ECR, so:

```bash
npx aws-cdk deploy MssPortfolioData --require-approval never
../scripts/push-image.sh <tag>
npx aws-cdk deploy --all --require-approval never -c image_tag=<tag>
```

Use the commit SHA as the tag. `image_tag` defaults to `latest`, which is fine locally
but never for a real deploy.

Always run `npx aws-cdk diff` first. Renaming or moving a construct changes its logical
ID, which replaces the resource. `MssPortfolioData` holds the table and the registry, so
check that stack's diff especially carefully.

## Rolling back

Redeploy a known-good tag. The image is immutable, so this is enough:

```bash
npx aws-cdk deploy MssPortfolioApi -c image_tag=<previous-sha>
```

ECS has a deployment circuit breaker with rollback enabled, so a task that never reaches
a healthy state reverts on its own.

## Verifying

Run these after any deploy. The bypass check is the one that matters most, because it is
the only one that fails silently.

```bash
curl -s -o /dev/null -w '%{http_code}\n' https://mountjoy.io/
curl -s https://mountjoy.io/api/v1/health
curl -s -o /dev/null -w '%{http_code}\n' https://mountjoy.io/api/v1/projects/nope
curl -s -o /dev/null -w '%{http_code}\n' --max-time 15 https://api.mountjoy.io/api/v1/health
```

Expected: 200, a JSON health body naming the deployed tag, **404**, and a timeout.

A 200 on the last one means the load balancer is open to the internet and the CloudFront
prefix list restriction is being bypassed. Check `open=False` on the listener in
`infra/stacks/api.py`.

A 200 on the third means CloudFront error responses are rewriting API errors. Nothing
should add custom error responses to the distribution.

## Publishing the frontend

```bash
cd frontend && flutter build web --release
aws s3 sync build/web "s3://$(aws cloudformation describe-stacks \
  --stack-name MssPortfolioSite \
  --query 'Stacks[0].Outputs[?OutputKey==`SiteBucketName`].OutputValue' \
  --output text)" --delete --cache-control "public, max-age=0, must-revalidate"
```

Then invalidate `/*` on the distribution. Do not cache these assets harder: Flutter does
not content-hash `main.dart.js`.

## When a deploy fails

`cdk deploy --verbose`, then the first `_FAILED` event:

```bash
aws cloudformation describe-stack-events --stack-name <stack> \
  --query 'StackEvents[?ResourceStatus==`CREATE_FAILED`||ResourceStatus==`UPDATE_FAILED`].[LogicalResourceId,ResourceStatusReason]' \
  --output text
```

For a task that starts and dies, read the container logs in the `api` log group and check
`stoppedReason` on the task. A 502 through CloudFront with a healthy ALB target is
almost always the origin domain or certificate mismatch described in CLAUDE.md.
