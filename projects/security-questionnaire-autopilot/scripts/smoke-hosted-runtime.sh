#!/usr/bin/env bash
set -euo pipefail

# Smoke-check a deployed hosted runtime using the public workflow API endpoints.
#
# Usage:
#   smoke-hosted-runtime.sh <BASE_URL>
#
# Env:
#   REQUIRE_SUPABASE_ENV=1|0       (default: 1) require env-health to show Supabase env booleans true
#   REQUIRE_SUPABASE_HEALTH=1|0    (default: 0) also require /api/workflow/supabase-health ok=true

usage() {
  cat >&2 <<'EOF'
Usage:
  smoke-hosted-runtime.sh <BASE_URL>
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

BASE_URL="${1:-}"
if [ -z "${BASE_URL:-}" ]; then
  echo "Missing BASE_URL argument" >&2
  usage
  exit 2
fi

require_bin() {
  local name="$1"
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "Missing dependency: $name" >&2
    exit 2
  fi
}

require_bin curl
require_bin jq

normalize_origin() {
  local u="$1"
  if [[ "$u" != http://* && "$u" != https://* ]]; then
    u="https://$u"
  fi
  u="$(printf '%s' "$u" | sed -E 's#^(https?://[^/]+).*$#\\1#')"
  u="${u%/}"
  printf '%s' "$u"
}

REQUIRE_SUPABASE_ENV="${REQUIRE_SUPABASE_ENV:-1}"
REQUIRE_SUPABASE_HEALTH="${REQUIRE_SUPABASE_HEALTH:-0}"

base="$(normalize_origin "$BASE_URL")"

echo "BASE_URL=$base" >&2

env_out="$(mktemp)"
code="$(curl -sS -m 12 -o "$env_out" -w "%{http_code}" "${base}/api/workflow/env-health" || echo "000")"
if [ "$code" != "200" ]; then
  echo "env-health failed (HTTP $code): ${base}/api/workflow/env-health" >&2
  cat "$env_out" >&2 || true
  rm -f "$env_out"
  exit 2
fi
if ! jq -e '.ok == true' "$env_out" >/dev/null 2>&1; then
  echo "env-health JSON ok!=true" >&2
  jq . "$env_out" >&2 || true
  rm -f "$env_out"
  exit 2
fi
if [ "$REQUIRE_SUPABASE_ENV" = "1" ] || [ "$REQUIRE_SUPABASE_ENV" = "true" ]; then
  if ! jq -e '.env.NEXT_PUBLIC_SUPABASE_URL == true and .env.SUPABASE_SERVICE_ROLE_KEY == true' "$env_out" >/dev/null 2>&1; then
    echo "env-health missing required Supabase env booleans" >&2
    jq . "$env_out" >&2 || true
    rm -f "$env_out"
    exit 2
  fi
fi
rm -f "$env_out"

if [ "$REQUIRE_SUPABASE_HEALTH" = "1" ] || [ "$REQUIRE_SUPABASE_HEALTH" = "true" ]; then
  sup_out="$(mktemp)"
  code="$(curl -sS -m 12 -o "$sup_out" -w "%{http_code}" "${base}/api/workflow/supabase-health?requireSeed=1&requirePilotDeals=1" || echo "000")"
  if [ "$code" != "200" ]; then
    echo "supabase-health failed (HTTP $code): ${base}/api/workflow/supabase-health" >&2
    cat "$sup_out" >&2 || true
    rm -f "$sup_out"
    exit 2
  fi
  if ! jq -e '.ok == true' "$sup_out" >/dev/null 2>&1; then
    echo "supabase-health JSON ok!=true" >&2
    jq . "$sup_out" >&2 || true
    rm -f "$sup_out"
    exit 2
  fi
  rm -f "$sup_out"
fi

echo "ok"

