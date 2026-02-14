#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/devops/run-sq-autopilot-hosted-integration.sh [flags]

Flags:
  --repo OWNER/REPO               (default: junhengz/auto-company)
  --ref REF                       Git ref for workflow file (default: main)
  --base-url URL                  Optional. If set, also writes repo var HOSTED_WORKFLOW_BASE_URL
  --require-supabase-env true|false    (default: true)
  --require-supabase-health true|false (default: false)
  --wait                          Wait for the run to complete and print conclusion

Examples:
  # Use repo variable HOSTED_WORKFLOW_BASE_URL:
  scripts/devops/run-sq-autopilot-hosted-integration.sh --repo junhengz/auto-company --wait

  # Override BASE_URL just for this dispatch (also persists it into repo variable):
  scripts/devops/run-sq-autopilot-hosted-integration.sh \
    --repo junhengz/auto-company \
    --base-url "https://auto-company-sq-autopilot.fly.dev" \
    --require-supabase-health false \
    --wait
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

require_bin() {
  local name="$1"
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "Missing dependency: $name" >&2
    exit 2
  fi
}

require_bin gh
require_bin jq

REPO="junhengz/auto-company"
REF="main"
BASE_URL=""
REQUIRE_SUPABASE_ENV="true"
REQUIRE_SUPABASE_HEALTH="false"
WAIT="0"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo) REPO="${2:-}"; shift 2 ;;
    --ref) REF="${2:-}"; shift 2 ;;
    --base-url) BASE_URL="${2:-}"; shift 2 ;;
    --require-supabase-env) REQUIRE_SUPABASE_ENV="${2:-}"; shift 2 ;;
    --require-supabase-health) REQUIRE_SUPABASE_HEALTH="${2:-}"; shift 2 ;;
    --wait) WAIT="1"; shift 1 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

WF="sq-autopilot-hosted-integration.yml"

if [ -n "${BASE_URL:-}" ]; then
  echo "Setting repo variable HOSTED_WORKFLOW_BASE_URL=${BASE_URL} on ${REPO}" >&2
  gh variable set HOSTED_WORKFLOW_BASE_URL -R "$REPO" --body "$BASE_URL" >/dev/null
fi

args=(
  workflow run "$WF"
  -R "$REPO"
  --ref "$REF"
  -f "require_supabase_env=${REQUIRE_SUPABASE_ENV}"
  -f "require_supabase_health=${REQUIRE_SUPABASE_HEALTH}"
)

if [ -n "${BASE_URL:-}" ]; then
  args+=(-f "base_url=${BASE_URL}")
fi

echo "Dispatching ${REPO}:${REF} workflow=${WF}" >&2
gh "${args[@]}" >/dev/null

if [ "$WAIT" != "1" ]; then
  echo "Dispatched. Next: gh run list -R \"$REPO\" --workflow \"$WF\" -L 3" >&2
  exit 0
fi

echo "Waiting for run to appear..." >&2
run_id=""
for _ in $(seq 1 30); do
  run_id="$(
    gh run list -R "$REPO" --workflow "$WF" -L 1 --json databaseId --jq '.[0].databaseId' 2>/dev/null || true
  )"
  if [ -n "${run_id:-}" ] && [ "${run_id:-null}" != "null" ]; then
    break
  fi
  sleep 2
done

if [ -z "${run_id:-}" ] || [ "${run_id:-null}" = "null" ]; then
  echo "Failed to locate the dispatched run id for workflow=${WF} in repo=${REPO}." >&2
  exit 2
fi

echo "Run: $(gh run view -R "$REPO" "$run_id" --json url --jq .url)" >&2

echo "Waiting for completion..." >&2
gh run watch -R "$REPO" "$run_id" --exit-status
