#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/devops/gh-delete-hosted-workflow-base-url-candidates.sh --repo OWNER/REPO

Deletes repo variables:
  HOSTED_WORKFLOW_BASE_URL           (canonical)
  HOSTED_WORKFLOW_BASE_URL_CANDIDATES (legacy; best-effort)

Why:
  Avoid repeatedly dispatching Cycle 005 against a dead/ephemeral BASE_URL (common after tunnels).
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

REPO=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo) REPO="${2:-}"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

if [ -z "${REPO:-}" ]; then
  echo "Missing --repo OWNER/REPO" >&2
  usage
  exit 2
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "Missing dependency: gh" >&2
  exit 2
fi

# gh prompts for confirmation; feed "y" to remain non-interactive.
printf 'y\n' | gh variable delete HOSTED_WORKFLOW_BASE_URL -R "$REPO" >/dev/null 2>&1 || true
printf 'y\n' | gh variable delete HOSTED_WORKFLOW_BASE_URL_CANDIDATES -R "$REPO" >/dev/null 2>&1 || true
echo "Deleted $REPO variables: HOSTED_WORKFLOW_BASE_URL (+ legacy HOSTED_WORKFLOW_BASE_URL_CANDIDATES if present)" >&2
