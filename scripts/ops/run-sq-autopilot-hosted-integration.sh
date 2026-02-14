#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF' >&2
Usage:
  scripts/ops/run-sq-autopilot-hosted-integration.sh --repo OWNER/REPO [--ref REF] [--base-url https://origin] [--persist]

Purpose:
  1) Validate BASE_URL (non-tunnel) satisfies /api/workflow/env-health contract
  2) Optionally persist it into repo variable HOSTED_WORKFLOW_BASE_URL
  3) Dispatch sq-autopilot-hosted-integration workflow and print the run id

Notes:
  - Requires: gh, curl, jq
  - Does not attempt to deploy hosting. It assumes you already have a stable hosted runtime origin.
EOF
  exit 2
}

repo=""
ref="main"
base_url=""
persist="false"

while [ $# -gt 0 ]; do
  case "$1" in
    --repo) repo="${2:-}"; shift 2 ;;
    --ref) ref="${2:-}"; shift 2 ;;
    --base-url) base_url="${2:-}"; shift 2 ;;
    --persist) persist="true"; shift 1 ;;
    -h|--help) usage ;;
    *) echo "Unknown arg: $1" >&2; usage ;;
  esac
done

test -n "${repo}" || usage

if [ -z "${base_url}" ]; then
  # Best-effort: read variable value via GitHub API. This may 403 on repos you can't administer.
  base_url="$(gh api -H 'Accept: application/vnd.github+json' "/repos/${repo}/actions/variables/HOSTED_WORKFLOW_BASE_URL" --jq '.value' 2>/dev/null || true)"
fi

if [ -z "${base_url}" ]; then
  echo "Missing BASE_URL. Provide --base-url or set repo variable HOSTED_WORKFLOW_BASE_URL on ${repo}." >&2
  exit 2
fi

base_url="${base_url%/}"

echo "Repo: ${repo}"
echo "Ref: ${ref}"
echo "BASE_URL: ${base_url}"

echo "Validating hosted runtime origin via env-health..."
BASE_URL="${base_url}" ./docs/qa-bach/cycle-029-hosted-workflow-origin-curl-commands-2026-02-14.sh

if [ "${persist}" = "true" ]; then
  echo "Persisting repo variable HOSTED_WORKFLOW_BASE_URL..."
  gh variable set HOSTED_WORKFLOW_BASE_URL -R "${repo}" --body "${base_url}"
fi

echo "Ensuring workflow exists on target repo..."
if ! gh workflow view sq-autopilot-hosted-integration -R "${repo}" >/dev/null 2>&1; then
  echo "Workflow sq-autopilot-hosted-integration not found on ${repo}." >&2
  echo "Fix: merge/push .github/workflows/sq-autopilot-hosted-integration.yml to that repo/ref, then retry." >&2
  exit 2
fi

echo "Dispatching workflow..."
gh workflow run sq-autopilot-hosted-integration.yml -R "${repo}" --ref "${ref}"

sleep 2
run_id="$(gh run list -R "${repo}" --workflow sq-autopilot-hosted-integration.yml --limit 1 --json databaseId --jq '.[0].databaseId')"
echo "Dispatched run_id=${run_id}"
echo "Watch:"
echo "  gh run watch -R \"${repo}\" \"${run_id}\" --exit-status"

