#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   BASE_URL="https://your-origin" ./docs/qa-bach/cycle-029-hosted-workflow-origin-curl-commands-2026-02-14.sh

BASE_URL="${BASE_URL:-}"
if [ -z "${BASE_URL}" ]; then
  echo "Missing BASE_URL (example: https://your-origin)" >&2
  exit 2
fi

BASE_URL="${BASE_URL%/}"

endpoint_env="${BASE_URL}/api/workflow/env-health"

mkdir -p /tmp/cycle-029-hosted-origin-check
out_dir="/tmp/cycle-029-hosted-origin-check"

hdr="${out_dir}/env-health.headers.txt"
body="${out_dir}/env-health.json"

code="$(curl -sS -m 12 -D "$hdr" -o "$body" -w "%{http_code}" "$endpoint_env" || echo "000")"
echo "env-health http_code=${code} endpoint=${endpoint_env}"

if [ "$code" != "200" ]; then
  echo "Non-200 from env-health. Check headers/body:" >&2
  echo "  $hdr" >&2
  echo "  $body" >&2
  exit 2
fi

if ! jq -e '.' "$body" >/dev/null 2>&1; then
  echo "env-health body is not JSON (likely wrong BASE_URL: marketing/static site)." >&2
  head -c 300 "$body" >&2 || true
  exit 2
fi

jq -e '.ok==true and .env.NEXT_PUBLIC_SUPABASE_URL==true and .env.SUPABASE_SERVICE_ROLE_KEY==true' "$body" >/dev/null

echo "PASS: env-health contract satisfied"
echo "Saved:"
echo "  $hdr"
echo "  $body"
