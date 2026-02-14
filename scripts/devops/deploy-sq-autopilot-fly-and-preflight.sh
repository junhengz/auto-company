#!/usr/bin/env bash
set -euo pipefail

# End-to-end helper for Cycle 005:
# - Deploy the hosted workflow runtime (`projects/security-questionnaire-autopilot`) to Fly.io
# - Ensure env-health returns 200 JSON with required env booleans true
# - Persist BASE_URL into GitHub repo variable HOSTED_WORKFLOW_BASE_URL
# - Dispatch Cycle 005 preflight-only (without local_runtime)
#
# Notes:
# - Uses Fly remote builder (no local Docker required).
# - Uses placeholder Supabase env values if none are provided; preflight uses
#   --preflight-require-supabase-health false by default.

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/devops/deploy-sq-autopilot-fly-and-preflight.sh [flags]

Flags:
  --app NAME                     Fly app name (default: auto-company-sq-autopilot)
  --region REGION                Fly primary region (default: iad)
  --repo OWNER/REPO              GitHub repo for variables/workflow (default: inferred via gh from current repo)
  --install-flyctl               Install flyctl if missing (uses https://fly.io/install.sh)
  --skip-preflight               Deploy + set variable, but do not dispatch Cycle 005 preflight
  --preflight-require-supabase-health true|false
                                 Default: false (only validates BASE_URL + env-health for bootstrap)

Env (optional):
  NEXT_PUBLIC_SUPABASE_URL
  SUPABASE_SERVICE_ROLE_KEY
  Note: if --preflight-require-supabase-health=true, these become REQUIRED (no placeholders).

Fly auth (required to deploy):
  Set FLY_API_TOKEN (recommended) or login interactively via:
    flyctl auth login
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

APP="auto-company-sq-autopilot"
REGION="iad"
REPO=""
INSTALL_FLYCTL="0"
SKIP_PREFLIGHT="0"
PREFLIGHT_REQUIRE_SUPABASE_HEALTH="false"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --app) APP="${2:-}"; shift 2 ;;
    --region) REGION="${2:-}"; shift 2 ;;
    --repo) REPO="${2:-}"; shift 2 ;;
    --install-flyctl) INSTALL_FLYCTL="1"; shift 1 ;;
    --skip-preflight) SKIP_PREFLIGHT="1"; shift 1 ;;
    --preflight-require-supabase-health) PREFLIGHT_REQUIRE_SUPABASE_HEALTH="${2:-}"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

require_bin() {
  local name="$1"
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "Missing dependency: $name" >&2
    exit 2
  fi
}

require_bin "gh"
require_bin "jq"
require_bin "curl"

if [ "${PREFLIGHT_REQUIRE_SUPABASE_HEALTH:-}" != "true" ] && [ "${PREFLIGHT_REQUIRE_SUPABASE_HEALTH:-}" != "false" ]; then
  echo "Invalid --preflight-require-supabase-health value: ${PREFLIGHT_REQUIRE_SUPABASE_HEALTH} (expected true|false)" >&2
  exit 2
fi

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
    echo "Insufficient GitHub repo permission to set variables or dispatch workflows." >&2
    echo "repo=$REPO viewerPermission=${perm:-unknown}" >&2
    echo "" >&2
    echo "Fix: re-run with --repo OWNER/REPO where you have >= WRITE access (e.g., your fork)." >&2
    exit 2
    ;;
esac

# Typical install path from https://fly.io/install.sh
if [ -x "${HOME}/.fly/bin/flyctl" ] && ! command -v flyctl >/dev/null 2>&1; then
  export PATH="${HOME}/.fly/bin:${PATH}"
fi

if ! command -v flyctl >/dev/null 2>&1; then
  if [ "$INSTALL_FLYCTL" = "1" ]; then
    "$(
      cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
    )/install-flyctl.sh"
  else
    echo "Missing dependency: flyctl" >&2
    echo "Fix:" >&2
    echo "  scripts/devops/install-flyctl.sh" >&2
    echo "  # or: curl -L https://fly.io/install.sh | sh" >&2
    echo "" >&2
    echo "Tip: re-run with --install-flyctl to auto-install." >&2
    exit 2
  fi
fi

# Prefer non-interactive token auth (best for automation).
FLY_ACCESS_TOKEN="${FLY_API_TOKEN:-}"
fly() {
  if [ -n "${FLY_ACCESS_TOKEN:-}" ]; then
    flyctl -t "$FLY_ACCESS_TOKEN" "$@"
  else
    flyctl "$@"
  fi
}

if ! fly auth whoami >/dev/null 2>&1; then
  echo "Fly auth missing." >&2
  echo "" >&2
  echo "Fix one of:" >&2
  echo "  1) Set FLY_API_TOKEN (recommended for non-interactive runs), then re-run:" >&2
  echo "     export FLY_API_TOKEN='...'" >&2
  echo "  2) Or login interactively:" >&2
  echo "     flyctl auth login" >&2
  echo "" >&2
  echo "Note: flyctl auth login requires completing a browser session (not great for headless shells)." >&2
  exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJ="$ROOT/projects/security-questionnaire-autopilot"
CONFIG="$PROJ/fly.toml"

if [ ! -f "$CONFIG" ]; then
  echo "Missing Fly config: $CONFIG" >&2
  exit 2
fi

echo "Ensuring Fly app exists: $APP" >&2
if ! fly apps show "$APP" >/dev/null 2>&1; then
  fly apps create "$APP"
fi

echo "Ensuring volume exists: runs (region=$REGION)" >&2
if ! fly volumes list --app "$APP" --json 2>/dev/null | jq -e '.[] | select(.Name=="runs")' >/dev/null; then
  fly volumes create runs --app "$APP" --region "$REGION" --size 1
fi

NEXT_PUBLIC_SUPABASE_URL="${NEXT_PUBLIC_SUPABASE_URL:-}"
SUPABASE_SERVICE_ROLE_KEY="${SUPABASE_SERVICE_ROLE_KEY:-}"

if [ -z "${NEXT_PUBLIC_SUPABASE_URL:-}" ] || [ -z "${SUPABASE_SERVICE_ROLE_KEY:-}" ]; then
  if [ "$PREFLIGHT_REQUIRE_SUPABASE_HEALTH" = "true" ]; then
    echo "Missing required Supabase env for strict preflight." >&2
    echo "" >&2
    echo "Fix:" >&2
    echo "  export NEXT_PUBLIC_SUPABASE_URL='https://<project-ref>.supabase.co'" >&2
    echo "  export SUPABASE_SERVICE_ROLE_KEY='...'" >&2
    exit 2
  fi

  # Bootstrap-only: set placeholders so env-health booleans are true; supabase-health is expected to fail.
  NEXT_PUBLIC_SUPABASE_URL="${NEXT_PUBLIC_SUPABASE_URL:-https://example.supabase.co}"
  SUPABASE_SERVICE_ROLE_KEY="${SUPABASE_SERVICE_ROLE_KEY:-service_role_placeholder}"
fi

echo "Setting hosted runtime secrets (env-health booleans must be true)..." >&2
fly secrets set \
  NEXT_PUBLIC_SUPABASE_URL="$NEXT_PUBLIC_SUPABASE_URL" \
  SUPABASE_SERVICE_ROLE_KEY="$SUPABASE_SERVICE_ROLE_KEY" \
  --app "$APP" >/dev/null

echo "Deploying (remote builder)..." >&2
(
  cd "$PROJ"
  fly deploy --app "$APP" --config "$CONFIG" --remote-only
)

BASE_URL="https://${APP}.fly.dev"
echo "Probing env-health: ${BASE_URL}/api/workflow/env-health" >&2
body="$(mktemp)"
for _i in $(seq 1 30); do
  code="$(curl -sS -m 20 -o "$body" -w "%{http_code}" "${BASE_URL}/api/workflow/env-health" || echo "000")"
  if [ "$code" = "200" ]; then
    break
  fi
  sleep 1
done
if [ "$code" != "200" ]; then
  echo "env-health failed (HTTP $code): ${BASE_URL}/api/workflow/env-health" >&2
  head -c 200 "$body" >&2 || true
  rm -f "$body"
  exit 1
fi
if ! jq -e '.ok == true and .env.NEXT_PUBLIC_SUPABASE_URL == true and .env.SUPABASE_SERVICE_ROLE_KEY == true' "$body" >/dev/null; then
  echo "env-health JSON did not satisfy required booleans. Response:" >&2
  cat "$body" >&2
  rm -f "$body"
  exit 1
fi
rm -f "$body"

# Guardrail: ensure we never persist an ephemeral tunnel origin into repo variables.
"$ROOT/projects/security-questionnaire-autopilot/scripts/validate-base-url-candidates.sh" --validate-only \
  "$BASE_URL" >/dev/null

echo "Setting repo variable HOSTED_WORKFLOW_BASE_URL -> $BASE_URL" >&2
gh variable set HOSTED_WORKFLOW_BASE_URL -R "$REPO" --body "$BASE_URL" >/dev/null
echo "Setting repo variable HOSTED_WORKFLOW_BASE_URL_CANDIDATES -> $BASE_URL (compat for older workflows)" >&2
gh variable set HOSTED_WORKFLOW_BASE_URL_CANDIDATES -R "$REPO" --body "$BASE_URL" >/dev/null

if [ "$SKIP_PREFLIGHT" = "1" ]; then
  echo "Skip preflight requested; done." >&2
  exit 0
fi

echo "Dispatching Cycle 005 preflight-only (no local_runtime)..." >&2
"$ROOT/scripts/devops/run-cycle-005-hosted-persistence-evidence.sh" \
  --repo "$REPO" \
  --preflight-only \
  --preflight-require-supabase-health "$PREFLIGHT_REQUIRE_SUPABASE_HEALTH"
