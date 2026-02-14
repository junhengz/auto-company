#!/usr/bin/env bash
set -euo pipefail

# Cycle 005 deterministic "no secrets" evidence path.
# Always produces a machine-checkable artifact under docs/operations-pg/,
# even when Supabase provisioning secrets are unavailable.
#
# Strategy:
# 1) Always run static bundle verification (no Postgres required).
# 2) Optionally run Postgres service apply+verify via GitHub Actions if `gh` is
#    installed and authenticated (still no Supabase secrets required).

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/cycle-005/run-no-secrets-evidence.sh [flags]

Flags:
  --repo OWNER/REPO   optional; used only for the GitHub Actions step
  --ref REF           optional ref for workflow dispatch (GitHub Actions step)
  --sql-bundle PATH   (default: projects/security-questionnaire-autopilot/supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql)
  --out-dir DIR       (default: docs/operations-pg/cycle-005/no-secrets-evidence)
  --skip-gha          skip the GitHub Actions step (always runs static verify)

Outputs (under --out-dir):
  manifest-<ts>.json   machine-checkable run manifest (what executed + where evidence landed)
  latest.json          copy of the most recent manifest
  static/              evidence from scripts/devops/run-cycle-005-static-bundle-verify-evidence.sh
  gha/                 evidence from scripts/devops/run-cycle-005-fallback-postgres-service-evidence.sh (if executed)
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

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

REPO=""
REF=""
SQL_BUNDLE="projects/security-questionnaire-autopilot/supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql"
OUT_DIR="$ROOT/docs/operations-pg/cycle-005/no-secrets-evidence"
SKIP_GHA="0"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo) REPO="${2:-}"; shift 2 ;;
    --ref) REF="${2:-}"; shift 2 ;;
    --sql-bundle) SQL_BUNDLE="${2:-}"; shift 2 ;;
    --out-dir) OUT_DIR="${2:-}"; shift 2 ;;
    --skip-gha) SKIP_GHA="1"; shift 1 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

mkdir -p "$OUT_DIR"

ts="$(date -u +"%Y%m%dT%H%M%SZ")"
manifest="$OUT_DIR/manifest-$ts.json"

static_dir="$OUT_DIR/static"
gha_dir="$OUT_DIR/gha"

# 1) Static bundle verify (always).
require_bin node
require_bin sha256sum

static_ok="false"
static_latest=""
static_rc=0

set +e
"$ROOT/scripts/devops/run-cycle-005-static-bundle-verify-evidence.sh" \
  --bundle "$SQL_BUNDLE" \
  --out-dir "$static_dir" >/dev/null 2>&1
static_rc="$?"
set -e

if [ "$static_rc" -eq 0 ] && [ -f "$static_dir/latest.json" ]; then
  static_ok="true"
  static_latest="${static_dir#$ROOT/}/latest.json"
fi

# 2) GitHub Actions Postgres service apply+verify (best-effort).
gha_attempted="false"
gha_ok="false"
gha_run_id=""
gha_latest=""
gha_reason=""

if [ "$SKIP_GHA" = "0" ]; then
  if command -v gh >/dev/null 2>&1; then
    if gh auth status >/dev/null 2>&1; then
      gha_attempted="true"
      require_bin jq

      set +e
      gha_cmd=(
        "$ROOT/scripts/devops/run-cycle-005-fallback-postgres-service-evidence.sh"
        ${REPO:+--repo "$REPO"}
        ${REF:+--ref "$REF"}
        --sql-bundle "$SQL_BUNDLE"
        --out-dir "$gha_dir"
      )
      run_out="$("${gha_cmd[@]}" 2>&1)"
      gha_rc="$?"
      set -e

      # Extract run id from stderr/stdout content if present.
      gha_run_id="$(printf '%s\n' "$run_out" | sed -nE 's/^Run id: ([0-9]+)$/\\1/p' | tail -n 1 || true)"

      if [ "$gha_rc" -eq 0 ] && [ -f "$gha_dir/latest/supabase-verify.json" ]; then
        gha_ok="true"
        gha_latest="${gha_dir#$ROOT/}/latest/supabase-verify.json"
      else
        gha_reason="gha_failed_or_artifact_missing"
      fi
    else
      gha_reason="gh_not_authenticated"
    fi
  else
    gha_reason="gh_not_installed"
  fi
else
  gha_reason="skip_gha_flag"
fi

repo_git_sha="$(cd "$ROOT" && git rev-parse HEAD 2>/dev/null || true)"

REPO_GIT_SHA="$repo_git_sha" \
SQL_BUNDLE_IN="$SQL_BUNDLE" \
OUT_DIR_IN="${OUT_DIR#$ROOT/}" \
STATIC_OK_IN="$static_ok" \
STATIC_RC_IN="$static_rc" \
STATIC_LATEST_IN="$static_latest" \
GHA_ATTEMPTED_IN="$gha_attempted" \
GHA_OK_IN="$gha_ok" \
GHA_RUN_ID_IN="$gha_run_id" \
GHA_LATEST_IN="$gha_latest" \
GHA_REASON_IN="$gha_reason" \
node - <<'NODE' >"$manifest"
function toBool(s) {
  return String(s).toLowerCase() === "true";
}
function toNumOrNull(s) {
  const t = String(s || "").trim();
  if (!t) return null;
  const n = Number(t);
  return Number.isFinite(n) ? n : null;
}
function toStrOrNull(s) {
  const t = String(s || "").trim();
  return t ? t : null;
}

const data = {
  checked_at_utc: new Date().toISOString(),
  repo_git_sha: toStrOrNull(process.env.REPO_GIT_SHA),
  inputs: {
    sql_bundle: toStrOrNull(process.env.SQL_BUNDLE_IN),
    out_dir: toStrOrNull(process.env.OUT_DIR_IN),
  },
  steps: {
    static_bundle_verify: {
      attempted: true,
      ok: toBool(process.env.STATIC_OK_IN),
      exit_code: toNumOrNull(process.env.STATIC_RC_IN),
      latest_evidence: toStrOrNull(process.env.STATIC_LATEST_IN),
    },
    gha_postgres_service_apply_verify: {
      attempted: toBool(process.env.GHA_ATTEMPTED_IN),
      ok: toBool(process.env.GHA_OK_IN),
      run_id: toNumOrNull(process.env.GHA_RUN_ID_IN),
      latest_evidence: toStrOrNull(process.env.GHA_LATEST_IN),
      reason: toStrOrNull(process.env.GHA_REASON_IN),
    },
  },
};

process.stdout.write(JSON.stringify(data, null, 2) + "\n");
NODE

cp "$manifest" "$OUT_DIR/latest.json"

echo "Wrote: ${manifest#$ROOT/}" >&2
echo "Latest: ${OUT_DIR#$ROOT/}/latest.json" >&2
