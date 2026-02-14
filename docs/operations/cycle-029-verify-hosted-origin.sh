#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${1:-}"

usage() {
  cat >&2 <<'EOF'
Usage:
  cycle-029-verify-hosted-origin.sh <BASE_URL>

Checks:
  - GET <BASE_URL>/api/workflow/env-health returns 200 JSON
  - .ok == true
  - .env.NEXT_PUBLIC_SUPABASE_URL == true
  - .env.SUPABASE_SERVICE_ROLE_KEY == true
EOF
}

if [ -z "${BASE_URL}" ] || [ "${BASE_URL}" = "-h" ] || [ "${BASE_URL}" = "--help" ]; then
  usage
  exit 2
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "Missing dependency: curl" >&2
  exit 2
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "Missing dependency: jq" >&2
  exit 2
fi

# Normalize: accept bare hostname, and strip to origin.
if [[ "${BASE_URL}" != http://* && "${BASE_URL}" != https://* ]]; then
  BASE_URL="https://${BASE_URL}"
fi
BASE_URL="$(printf '%s' "$BASE_URL" | sed -E 's#^(https?://[^/]+).*$#\\1#')"
BASE_URL="${BASE_URL%/}"

endpoint="${BASE_URL}/api/workflow/env-health"
tmp="$(mktemp)"
hdr="$(mktemp)"
trap 'rm -f "$tmp" "$hdr"' EXIT

code="$(curl -sS -m 12 -D "$hdr" -o "$tmp" -w "%{http_code}" "$endpoint" || echo "000")"
if [ "$code" != "200" ]; then
  echo "FAIL: env-health HTTP $code: $endpoint" >&2
  ctype="$(grep -i '^content-type:' "$hdr" 2>/dev/null | head -n 1 || true)"
  [ -n "$ctype" ] && echo "content-type: $ctype" >&2
  head -c 240 "$tmp" >&2 || true
  exit 2
fi

if ! jq -e '.' "$tmp" >/dev/null 2>&1; then
  echo "FAIL: env-health is not JSON: $endpoint" >&2
  ctype="$(grep -i '^content-type:' "$hdr" 2>/dev/null | head -n 1 || true)"
  [ -n "$ctype" ] && echo "content-type: $ctype" >&2
  head -c 240 "$tmp" >&2 || true
  exit 2
fi

ok="$(jq -r '.ok == true' "$tmp" 2>/dev/null || echo "false")"
has_pub="$(jq -r '.env.NEXT_PUBLIC_SUPABASE_URL == true' "$tmp" 2>/dev/null || echo "false")"
has_srv="$(jq -r '.env.SUPABASE_SERVICE_ROLE_KEY == true' "$tmp" 2>/dev/null || echo "false")"
provider="$(jq -r '.deploy.provider // "unknown"' "$tmp" 2>/dev/null || echo "unknown")"

echo "BASE_URL: ${BASE_URL}"
echo "provider: ${provider}"
echo "ok: ${ok}"
echo "has NEXT_PUBLIC_SUPABASE_URL: ${has_pub}"
echo "has SUPABASE_SERVICE_ROLE_KEY: ${has_srv}"

if [ "$ok" != "true" ] || [ "$has_pub" != "true" ] || [ "$has_srv" != "true" ]; then
  echo "" >&2
  echo "FAIL: env-health did not meet hosted persistence preflight requirements." >&2
  echo "Raw JSON (booleans only, safe):" >&2
  jq '{ok, deploy, env}' "$tmp" >&2 || cat "$tmp" >&2 || true
  exit 2
fi

echo "PASS: hosted workflow runtime origin is valid for Cycle 005 preflight."

