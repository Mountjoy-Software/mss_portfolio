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

if [ ! -d frontend/build/web ]; then
  echo "frontend/build/web is missing, building it"
  (cd frontend && flutter build web --release)
fi

exec docker compose "$@"
