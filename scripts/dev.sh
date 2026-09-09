#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [ ! -f .env ] && [ -z "${ANTHROPIC_API_KEY:-}" ]; then
  cat >&2 <<'MSG'
No .env found and ANTHROPIC_API_KEY is unset.

Create it once with the key from Secrets Manager
(mss-portfolio/anthropic-api-key):

    printf 'ANTHROPIC_API_KEY=%s\n' 'sk-ant-...' > .env
    chmod 600 .env

.env is gitignored. Compose reads it automatically.
MSG
  exit 1
fi

export AWS_PROFILE="${AWS_PROFILE:-mss}"
export AWS_REGION="${AWS_REGION:-us-east-1}"

if [ -z "${AWS_ACCESS_KEY_ID:-}" ]; then
  if ! creds=$(aws configure export-credentials --format env-no-export 2>/dev/null); then
    echo "Could not export AWS credentials. Run: aws login --profile $AWS_PROFILE" >&2
    exit 1
  fi
  set -a
  eval "$creds"
  set +a
fi

if [ ! -d frontend/build/web ]; then
  echo "frontend/build/web is missing, building it"
  (cd frontend && flutter build web --release)
fi

exec docker compose "$@"
