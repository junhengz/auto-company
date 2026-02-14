#!/usr/bin/env bash
set -euo pipefail

# Operator wrapper: dispatch cycle-005-hosted-persistence-evidence workflow via gh.
#
# Canonical hosted origin governance:
# - CI uses a single repo variable: HOSTED_WORKFLOW_BASE_URL
# - This wrapper can (optionally) set that variable, or let the workflow persist it.
#
# Compatibility note:
# - The workflow inputs in `.github/workflows/cycle-005-hosted-persistence-evidence.yml` have changed over
#   time (e.g., `persist_base_url_candidates` vs `persist_hosted_workflow_base_url`).
# - This wrapper auto-detects supported inputs from GitHub and maps flags accordingly to avoid HTTP 422
#   "Unexpected inputs provided" failures.

usage() {
  cat >&2 <<'USAGE'
Usage:
  scripts/devops/run-cycle-005-hosted-persistence-evidence.sh [flags]

Flags:
  --repo OWNER/REPO              (default: inferred via gh from current repo)
  --ref REF                      Git ref to run workflow from (branch/tag/SHA)

  --base-url URL                 Optional override BASE_URL (single origin). If empty, workflow uses repo variable HOSTED_WORKFLOW_BASE_URL.
  --set-variable                 Write --base-url into repo variable HOSTED_WORKFLOW_BASE_URL before dispatch
  --persist-hosted-base-url      Dispatch with persist_hosted_workflow_base_url=true (workflow will upsert HOSTED_WORKFLOW_BASE_URL)

  --local-runtime                Dispatch with local_runtime=true (ephemeral Next.js runtime inside the GHA job; NOT a production origin)

  --preflight-only               Dispatch with preflight_only=true (default in the workflow)
  --full                         Dispatch with preflight_only=false (runs intake + DB evidence capture + PR creation)
  --enable-autorun-after-preflight
                                 Dispatch with preflight_only=true + enable_autorun_after_preflight=true (workflow sets CYCLE_005_AUTORUN_ENABLED=true after a green preflight)
  --autorun true|false           Set repo variable CYCLE_005_AUTORUN_ENABLED (enables/disables scheduled evidence runs)
  --enable-autorun               Alias for --autorun true
  --disable-autorun              Alias for --autorun false

  --preflight-require-supabase-health true|false
                                 Default: true. Set false only to validate BASE_URL + env-health while Supabase is not yet provisioned.

  --run-id RUN_ID                Optional explicit run id
  --skip-sql-apply true|false    (default: true)
  --sql-bundle PATH              (default: projects/security-questionnaire-autopilot/supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql)
  --require-fallback-secrets     Enforce NEXT_PUBLIC_SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY secrets exist (off by default)

Notes:
  - Requires gh CLI authenticated.
  - Candidate scanning via HOSTED_WORKFLOW_BASE_URL_CANDIDATES is intentionally not supported.
USAGE
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

gh auth status -h github.com >/dev/null

REPO=""
REF=""
BASE_URL=""
SET_VARIABLE="0"
PERSIST_HOSTED_BASE_URL="false"
LOCAL_RUNTIME="false"

PREFLIGHT_ONLY="" # empty means use workflow default
AUTORUN=""
ENABLE_AUTORUN_AFTER_PREFLIGHT="false"
PREFLIGHT_REQUIRE_SUPABASE_HEALTH="true"
RUN_ID=""
SKIP_SQL_APPLY="true"
SQL_BUNDLE="projects/security-questionnaire-autopilot/supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql"
REQUIRE_FALLBACK_SECRETS="false"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo) REPO="${2:-}"; shift 2 ;;
    --ref) REF="${2:-}"; shift 2 ;;

    --base-url) BASE_URL="${2:-}"; shift 2 ;;
    --set-variable) SET_VARIABLE="1"; shift 1 ;;
    --persist-hosted-base-url) PERSIST_HOSTED_BASE_URL="true"; shift 1 ;;

    --local-runtime) LOCAL_RUNTIME="true"; shift 1 ;;

    --preflight-only) PREFLIGHT_ONLY="true"; shift 1 ;;
    --full) PREFLIGHT_ONLY="false"; shift 1 ;;
    --autorun) AUTORUN="${2:-}"; shift 2 ;;
    --enable-autorun) AUTORUN="true"; shift 1 ;;
    --disable-autorun) AUTORUN="false"; shift 1 ;;
    --enable-autorun-after-preflight) ENABLE_AUTORUN_AFTER_PREFLIGHT="true"; shift 1 ;;

    --preflight-require-supabase-health) PREFLIGHT_REQUIRE_SUPABASE_HEALTH="${2:-}"; shift 2 ;;

    --run-id) RUN_ID="${2:-}"; shift 2 ;;
    --skip-sql-apply) SKIP_SQL_APPLY="${2:-}"; shift 2 ;;
    --sql-bundle) SQL_BUNDLE="${2:-}"; shift 2 ;;
    --require-fallback-secrets) REQUIRE_FALLBACK_SECRETS="true"; shift 1 ;;

    *)
      echo "Unknown arg: $1" >&2
      usage
      exit 2
      ;;
  esac
done

if [ -z "${REPO:-}" ]; then
  REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)"
fi
if [ -z "${REPO:-}" ]; then
  echo "Could not infer --repo. Re-run with: --repo OWNER/REPO" >&2
  exit 2
fi

perm="$(gh repo view "$REPO" --json viewerPermission -q .viewerPermission 2>/dev/null || echo "")"
case "$perm" in
  ADMIN|MAINTAIN|WRITE) ;;
  *)
    echo "Insufficient GitHub repo permission to dispatch workflows or set variables." >&2
    echo "repo=$REPO viewerPermission=${perm:-unknown}" >&2
    echo "Fix: run as a maintainer (>= WRITE) or ask an admin to run the workflow in the GitHub UI." >&2
    exit 2
    ;;
esac

if [ "$LOCAL_RUNTIME" = "true" ]; then
  # local_runtime mode is for repos with no externally hosted BASE_URL yet.
  PREFLIGHT_ONLY="true"
  PREFLIGHT_REQUIRE_SUPABASE_HEALTH="false"
  # Persisting a local tunnel/localhost origin is never correct.
  PERSIST_HOSTED_BASE_URL="false"
  SET_VARIABLE="0"
fi

if [ -n "${AUTORUN:-}" ]; then
  if [ "$AUTORUN" != "true" ] && [ "$AUTORUN" != "false" ]; then
    echo "Invalid --autorun value: $AUTORUN (expected true|false)" >&2
    exit 2
  fi
  gh variable set CYCLE_005_AUTORUN_ENABLED -R "$REPO" --body "$AUTORUN" >/dev/null
  echo "Set repo variable CYCLE_005_AUTORUN_ENABLED=${AUTORUN}" >&2
fi

if [ "$SET_VARIABLE" = "1" ]; then
  if [ -z "${BASE_URL:-}" ]; then
    echo "--set-variable requires --base-url" >&2
    exit 2
  fi
  # For backward compatibility with older workflow versions that still read HOSTED_WORKFLOW_BASE_URL_CANDIDATES,
  # set both to the same single stable origin.
  gh variable set HOSTED_WORKFLOW_BASE_URL -R "$REPO" --body "$BASE_URL" >/dev/null
  echo "Set repo variable HOSTED_WORKFLOW_BASE_URL=${BASE_URL}" >&2
  gh variable set HOSTED_WORKFLOW_BASE_URL_CANDIDATES -R "$REPO" --body "$BASE_URL" >/dev/null 2>&1 || true
  echo "Set repo variable HOSTED_WORKFLOW_BASE_URL_CANDIDATES=${BASE_URL} (best-effort compat)" >&2
fi

wf="cycle-005-hosted-persistence-evidence.yml"
args=(workflow run "$wf" -R "$REPO")

if [ -n "${REF:-}" ]; then
  args+=(--ref "$REF")
fi

# Detect supported workflow_dispatch input names from GitHub to avoid 422 errors.
wf_yaml="$(mktemp)"
if ! gh workflow view "$wf" -R "$REPO" --yaml >"$wf_yaml" 2>/dev/null; then
  echo "Failed to fetch workflow YAML from GitHub: $REPO/$wf" >&2
  rm -f "$wf_yaml"
  exit 2
fi

supports_persist_hosted_base_url="0"
supports_persist_base_url_candidates="0"
supports_base_url_candidates_alias="0"

if rg -q '^[[:space:]]+persist_hosted_workflow_base_url:' "$wf_yaml"; then
  supports_persist_hosted_base_url="1"
fi
if rg -q '^[[:space:]]+persist_base_url_candidates:' "$wf_yaml"; then
  supports_persist_base_url_candidates="1"
fi
if rg -q '^[[:space:]]+base_url_candidates:' "$wf_yaml"; then
  supports_base_url_candidates_alias="1"
fi
rm -f "$wf_yaml"

# Only pass preflight_only if the operator explicitly set it; otherwise leave workflow default.
if [ -n "${PREFLIGHT_ONLY:-}" ]; then
  args+=(-f "preflight_only=${PREFLIGHT_ONLY}")
fi

args+=(
  -f "local_runtime=${LOCAL_RUNTIME}"
  -f "enable_autorun_after_preflight=${ENABLE_AUTORUN_AFTER_PREFLIGHT}"
  -f "base_url=${BASE_URL}"
  -f "run_id=${RUN_ID}"
  -f "skip_sql_apply=${SKIP_SQL_APPLY}"
  -f "preflight_require_supabase_health=${PREFLIGHT_REQUIRE_SUPABASE_HEALTH}"
  -f "sql_bundle=${SQL_BUNDLE}"
  -f "require_fallback_supabase_secrets=${REQUIRE_FALLBACK_SECRETS}"
)

# Map persistence flag to the supported input name.
if [ "$supports_persist_hosted_base_url" = "1" ]; then
  args+=(-f "persist_hosted_workflow_base_url=${PERSIST_HOSTED_BASE_URL}")
elif [ "$supports_persist_base_url_candidates" = "1" ]; then
  # Older workflow: persistence is about the candidate list variable.
  # If the operator requested canonical base-url persistence, we interpret it as persisting the single
  # origin into the candidates variable.
  if [ "$PERSIST_HOSTED_BASE_URL" = "true" ]; then
    args+=(-f "persist_base_url_candidates=true")
  else
    args+=(-f "persist_base_url_candidates=false")
  fi
fi

# Older workflow versions accept an alias `base_url_candidates`. Avoid sending it unless supported.
if [ "$supports_base_url_candidates_alias" = "1" ]; then
  args+=(-f "base_url_candidates=${BASE_URL}")
fi

echo "Dispatching: gh ${args[*]}" >&2
gh "${args[@]}" >/dev/null

echo "Dispatched workflow. Track it with:" >&2
echo "  gh run list -R \"$REPO\" --workflow \"$wf\" -L 5" >&2
