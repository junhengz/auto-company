#!/usr/bin/env bash
set -euo pipefail

# CTO (Vogels) deterministic Cycle 005 fallback path:
# - Apply + verify the SQL bundle against a vanilla Postgres GitHub Actions service container
# - No Supabase provisioning (Mgmt API) secrets required
# - Store role-owned evidence under docs/cto-vogels/

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/devops/run-cycle-005-cto-vogels-fallback-evidence.sh [flags]

Flags:
  --repo OWNER/REPO   (default: inferred via gh or git remote)
  --ref REF           optional ref for workflow dispatch
  --sql-bundle PATH   (default: projects/security-questionnaire-autopilot/supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql)
  --no-watch          dispatch only; do not wait and do not download artifacts (prints run id)
  --run-id ID         skip dispatch; only download artifacts for an existing run
  --out-dir DIR       (default: docs/cto-vogels/cycle-005/postgres-service-apply-verify)

Outputs (under --out-dir):
  evidence/
    supabase-verify-run-<runid>.json
    artifact-fetch-<ts>-run-<runid>.json
    artifacts/run-<runid>/...
  latest/
    supabase-verify.json          (copy of supabase-verify-run-<runid>.json)
    artifact-fetch.json           (copy of artifact-fetch-<ts>-run-<runid>.json)
    run.json                      (pointer manifest)
    report.json                   (machine-checkable summary for gates)
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
sha256_file() {
  local f="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$f" | awk '{print $1}'
    return 0
  fi
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$f" | awk '{print $1}'
    return 0
  fi
  echo "Missing dependency: sha256sum (or shasum)" >&2
  exit 2
}

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

REPO=""
REF=""
SQL_BUNDLE="projects/security-questionnaire-autopilot/supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql"
NO_WATCH="0"
RUN_ID=""
OUT_DIR="$ROOT/docs/cto-vogels/cycle-005/postgres-service-apply-verify"

passthrough=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo) REPO="${2:-}"; shift 2 ;;
    --ref) REF="${2:-}"; shift 2 ;;
    --sql-bundle) SQL_BUNDLE="${2:-}"; shift 2 ;;
    --no-watch) NO_WATCH="1"; shift 1 ;;
    --run-id) RUN_ID="${2:-}"; shift 2 ;;
    --out-dir) OUT_DIR="${2:-}"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

passthrough+=(--sql-bundle "$SQL_BUNDLE" --out-dir "$OUT_DIR")
if [ -n "${REPO:-}" ]; then passthrough+=(--repo "$REPO"); fi
if [ -n "${REF:-}" ]; then passthrough+=(--ref "$REF"); fi
if [ -n "${RUN_ID:-}" ]; then passthrough+=(--run-id "$RUN_ID"); fi
if [ "$NO_WATCH" = "1" ]; then passthrough+=(--no-watch); fi

"$ROOT/scripts/devops/run-cycle-005-fallback-postgres-service-evidence.sh" "${passthrough[@]}"

# Best-effort: write a small deterministic summary for downstream gating.
latest_dir="$OUT_DIR/latest"
verify_json="$latest_dir/supabase-verify.json"
run_json="$latest_dir/run.json"
report_json="$latest_dir/report.json"

bundle_abs="$ROOT/$SQL_BUNDLE"
bundle_sha256=""
bundle_bytes=""
if [ -f "$bundle_abs" ]; then
  bundle_sha256="$(sha256_file "$bundle_abs")"
  bundle_bytes="$(wc -c <"$bundle_abs" | tr -d ' ')"
fi

ok="null"
reason="null"
if [ -f "$verify_json" ]; then
  ok="$(jq -r '.ok // null' "$verify_json" 2>/dev/null || echo null)"
  reason="$(jq -r '.reason // null' "$verify_json" 2>/dev/null || echo null)"
fi

repo="null"
run_id="null"
workflow="null"
if [ -f "$run_json" ]; then
  repo="$(jq -r '.repo // null' "$run_json" 2>/dev/null || echo null)"
  run_id="$(jq -r '.run_id // null' "$run_json" 2>/dev/null || echo null)"
  workflow="$(jq -r '.workflow // null' "$run_json" 2>/dev/null || echo null)"
fi

jq -n \
  --arg checked_at_utc "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg out_dir "$OUT_DIR" \
  --arg latest_dir "$latest_dir" \
  --arg sql_bundle "$SQL_BUNDLE" \
  --arg bundle_sha256 "$bundle_sha256" \
  --arg bundle_bytes "$bundle_bytes" \
  --arg verify_path "$verify_json" \
  --arg run_path "$run_json" \
  --arg repo "$repo" \
  --arg run_id "$run_id" \
  --arg workflow "$workflow" \
  --arg ok "$ok" \
  --arg reason "$reason" \
  '{
    checked_at_utc: $checked_at_utc,
    mode: "fallback_postgres_service_apply_verify",
    github: {
      repo: (if $repo=="null" then null else $repo end),
      run_id: (if $run_id=="null" then null else ($run_id|tonumber) end),
      workflow: (if $workflow=="null" then null else $workflow end)
    },
    paths: {out_dir:$out_dir, latest_dir:$latest_dir, run:$run_path, supabase_verify:$verify_path},
    inputs: {sql_bundle:$sql_bundle},
    sql_bundle: {
      sha256: (if $bundle_sha256=="" then null else $bundle_sha256 end),
      bytes: (if $bundle_bytes=="" then null else ($bundle_bytes|tonumber) end)
    },
    result: {
      ok: (if $ok=="null" then null elif $ok=="true" then true elif $ok=="false" then false else null end),
      reason: (if $reason=="null" then null else $reason end)
    }
  }' >"$report_json"

echo "Report: $report_json" >&2
