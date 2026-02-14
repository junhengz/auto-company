#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/devops/gh-set-hosted-base-url-and-run-preflight.sh [options]

Options:
  --repo OWNER/REPO     GitHub repo to operate on (default: current repo via gh)
  --base-url URL        Stable hosted runtime origin, e.g. https://auto-company-sq-autopilot.fly.dev
  --set-canonical       Set repo variable HOSTED_WORKFLOW_BASE_URL=--base-url
  --set-candidates      Set repo variable HOSTED_WORKFLOW_BASE_URL_CANDIDATES=--base-url
  --run                Dispatch cycle-005-hosted-persistence-evidence as a preflight-only run
  --local-runtime       When used with --run, run preflight with local_runtime=true (no external hosting required)
  --require-supabase-health true|false
                        When used with --run, sets preflight_require_supabase_health (default: false)
  --ref REF             Git ref for workflow dispatch (default: repo default branch)

Examples:
  # Fork-friendly: set both variables to a stable origin and run preflight
  scripts/devops/gh-set-hosted-base-url-and-run-preflight.sh \
    --repo junhengz/auto-company \
    --base-url https://auto-company-sq-autopilot.fly.dev \
    --set-canonical --set-candidates --run

  # Blocked on hosting: still validate the runtime contract via local_runtime
  scripts/devops/gh-set-hosted-base-url-and-run-preflight.sh \
    --repo junhengz/auto-company \
    --run --local-runtime --require-supabase-health false
EOF
}

require_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || { echo "Missing required command: $cmd" >&2; exit 2; }
}

REPO=""
BASE_URL=""
SET_CANONICAL="false"
SET_CANDIDATES="false"
DO_RUN="false"
LOCAL_RUNTIME="false"
REQUIRE_SUPABASE_HEALTH="false"
REF=""

while [ $# -gt 0 ]; do
  case "$1" in
    --repo) REPO="${2:-}"; shift 2 ;;
    --base-url) BASE_URL="${2:-}"; shift 2 ;;
    --set-canonical) SET_CANONICAL="true"; shift 1 ;;
    --set-candidates) SET_CANDIDATES="true"; shift 1 ;;
    --run) DO_RUN="true"; shift 1 ;;
    --local-runtime) LOCAL_RUNTIME="true"; shift 1 ;;
    --require-supabase-health) REQUIRE_SUPABASE_HEALTH="${2:-}"; shift 2 ;;
    --ref) REF="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

require_cmd gh

if [ -z "${REPO:-}" ]; then
  REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
fi

if [ "${SET_CANONICAL}" = "true" ] || [ "${SET_CANDIDATES}" = "true" ]; then
  if [ -z "${BASE_URL:-}" ]; then
    echo "--base-url is required when using --set-canonical and/or --set-candidates" >&2
    exit 2
  fi
  if ! printf '%s' "$BASE_URL" | grep -Eq '^https?://[^/]+$'; then
    echo "--base-url must be a single origin (no path), got: ${BASE_URL}" >&2
    exit 2
  fi
fi

if [ "${SET_CANONICAL}" = "true" ]; then
  gh variable set HOSTED_WORKFLOW_BASE_URL -R "$REPO" --body "$BASE_URL" >/dev/null
  echo "Set $REPO variable HOSTED_WORKFLOW_BASE_URL=$BASE_URL"
fi

if [ "${SET_CANDIDATES}" = "true" ]; then
  gh variable set HOSTED_WORKFLOW_BASE_URL_CANDIDATES -R "$REPO" --body "$BASE_URL" >/dev/null
  echo "Set $REPO variable HOSTED_WORKFLOW_BASE_URL_CANDIDATES=$BASE_URL"
fi

if [ "${DO_RUN}" != "true" ]; then
  exit 0
fi

if [ "${REQUIRE_SUPABASE_HEALTH}" != "true" ] && [ "${REQUIRE_SUPABASE_HEALTH}" != "false" ]; then
  echo "--require-supabase-health must be true or false; got: ${REQUIRE_SUPABASE_HEALTH}" >&2
  exit 2
fi

args=(
  "local_runtime=${LOCAL_RUNTIME}"
  "preflight_only=true"
  "skip_sql_apply=true"
  "preflight_require_supabase_health=${REQUIRE_SUPABASE_HEALTH}"
  "enable_autorun_after_preflight=false"
  "require_fallback_supabase_secrets=false"
  "attempt_vercel_env_sync=false"
  "attempt_cloudflare_pages_env_sync=false"
)

cmd=(gh workflow run cycle-005-hosted-persistence-evidence -R "$REPO")
if [ -n "${REF:-}" ]; then
  cmd+=(--ref "$REF")
fi
for kv in "${args[@]}"; do
  cmd+=(-f "$kv")
done

echo "Dispatching cycle-005-hosted-persistence-evidence to $REPO (ref: ${REF:-<default>}) ..."
"${cmd[@]}" >/dev/null

run_id="$(gh run list -R "$REPO" --workflow cycle-005-hosted-persistence-evidence --limit 1 --json databaseId -q '.[0].databaseId')"
echo "Run: $run_id"
gh run watch -R "$REPO" "$run_id" --interval 10
