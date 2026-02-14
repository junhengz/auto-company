#!/usr/bin/env bash
set -euo pipefail

# Deterministically select the correct deployed Next.js workflow runtime BASE_URL.
#
# Priority order for candidate sources:
# 1) positional args (if provided)
# 2) HOSTED_WORKFLOW_BASE_URL (single canonical origin)
# 3) BASE_URL_CANDIDATES (accepted only if it normalizes to exactly one origin)
#
# Notes:
# - This script no longer scans/chooses among multi-candidate variables (e.g. HOSTED_WORKFLOW_BASE_URL_CANDIDATES).
# - If you want to probe multiple candidates, use:
#     ./projects/security-questionnaire-autopilot/scripts/discover-hosted-base-url.sh <candidate...>
#
# Output: prints the selected BASE_URL (single line) to stdout.

# Repo root (this script lives in projects/security-questionnaire-autopilot/scripts).
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
PROJECT="$ROOT/projects/security-questionnaire-autopilot"

RESOLVE_ONE="$PROJECT/scripts/resolve-hosted-workflow-base-url.sh"

usage() {
  cat >&2 <<'EOF'
Usage:
  select-hosted-base-url.sh [base_url]

Environment inputs (optional):
  HOSTED_WORKFLOW_BASE_URL
  BASE_URL_CANDIDATES

Notes:
  - This script enforces exactly one origin (no candidate scanning).
  - The result is validated by probing GET <BASE_URL>/api/workflow/env-health.
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

# This wrapper intentionally enforces a single origin.
if [ "$#" -gt 1 ]; then
  echo "Error: expected 0 or 1 argument (single origin); got $#." >&2
  echo "If you need to probe multiple candidates, run:" >&2
  echo "  ./projects/security-questionnaire-autopilot/scripts/discover-hosted-base-url.sh <candidate...>" >&2
  exit 2
fi

# Legacy vars are ignored (intentionally) to prevent CI poisoning via candidate lists.
if [ -n "${HOSTED_WORKFLOW_BASE_URL_CANDIDATES:-}" ] || \
   [ -n "${CYCLE_005_BASE_URL_CANDIDATES:-}" ] || \
   [ -n "${HOSTED_BASE_URL_CANDIDATES:-}" ] || \
   [ -n "${WORKFLOW_APP_BASE_URL_CANDIDATES:-}" ]; then
  echo "Warning: legacy multi-candidate BASE_URL vars are ignored (set HOSTED_WORKFLOW_BASE_URL instead)." >&2
fi

exec "$RESOLVE_ONE" "${1:-}"
