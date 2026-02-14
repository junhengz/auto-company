# Cycle 005: Set Supabase GitHub Actions Secrets (junhengz/auto-company)

## If You Do Not Have Supabase Provisioning Secrets
Use the deterministic fallback evidence path (no Supabase provisioning secrets required):

- `docs/cto-vogels/cycle-005-deterministic-fallback-no-secrets.md`
- `scripts/devops/run-cycle-005-cto-vogels-fallback-evidence.sh`

This runbook is only for enabling the Supabase Management API provisioning workflow.

## Goal
Unblock `.github/workflows/cycle-005-supabase-provision-apply-verify*.yml` by ensuring these GitHub Actions **repository secrets** exist in `junhengz/auto-company`:

- `SUPABASE_ACCESS_TOKEN`
- `SUPABASE_ORG_SLUG`
- `SUPABASE_DB_PASSWORD`

These are required for the workflow to provision a Supabase project (Mgmt API) and build `SUPABASE_DB_URL` for SQL apply.

## Current State (Observed)
As of `2026-02-14T03:50:11Z`, the repo is missing all three required secrets (names only). Evidence:
- `docs/qa-bach/cycle-018-gh-secrets-supabase-provision-junhengz_auto-company-20260214T035011Z-409309-12943.json`

## Preconditions (Operator)
- You have **repo Admin** (or equivalent) permissions on `junhengz/auto-company` to manage Actions secrets.
- You have a GitHub token available to `gh` as `GH_TOKEN` (recommended) with repo access appropriate for secret management.
- You have the secret values on hand (from your password manager / secure channel).

## Where To Get The Values (Supabase)
- `SUPABASE_ACCESS_TOKEN`: Supabase Dashboard account settings -> Access Tokens (create a PAT for automation).
- `SUPABASE_ORG_SLUG`: Supabase org identifier shown in the dashboard/org URL and org settings.
- `SUPABASE_DB_PASSWORD`: the Postgres password configured for the target project (reset if lost).

## Fast Path (CLI, < 5 minutes)
1. Authenticate `gh` (token only; do not paste secrets into command history):

```bash
export GH_TOKEN="..."   # GitHub PAT (repo admin or equivalent)
gh auth status -h github.com
```

2. Force set the required secrets (works even if the token cannot verify existing secrets due to `HTTP 403`):

```bash
export SUPABASE_ACCESS_TOKEN="..."   # Supabase PAT with org/project mgmt capability
export SUPABASE_ORG_SLUG="..."       # Supabase org slug (not secret, but stored as secret for consistency)
export SUPABASE_DB_PASSWORD="..."    # Postgres password used to build DB URL

scripts/devops/gh-ensure-supabase-provision-secrets.sh \
  --repo junhengz/auto-company \
  --set-all \
  --non-interactive
```

3. Verify (best-effort; depends on token permissions):

```bash
scripts/devops/gh-ensure-supabase-provision-secrets.sh --repo junhengz/auto-company --check-only
```

4. Re-run the end-to-end workflow wrapper:

```bash
scripts/devops/run-cycle-005-supabase-provision-apply-verify.sh --repo junhengz/auto-company
```

Acceptance check (after artifact download):

```bash
jq -e '.ok == true' docs/devops/evidence/supabase-verify-run-<RUN_ID>.json
```

## UI Path (If CLI Auth/Permissions Are Blocked)
1. Open GitHub repo: `junhengz/auto-company`
2. Go to: `Settings` -> `Secrets and variables` -> `Actions`
3. Add repository secrets with exact names:
   - `SUPABASE_ACCESS_TOKEN`
   - `SUPABASE_ORG_SLUG`
   - `SUPABASE_DB_PASSWORD`
4. Re-run:

```bash
scripts/devops/run-cycle-005-supabase-provision-apply-verify.sh --repo junhengz/auto-company
```

## Failure Modes (What To Do)
- `HTTP 403` during verification:
  - Your token can’t read/list secrets. Use `--set-all` (CLI) or the GitHub UI path.
- Workflow still fails early with “Missing secret: …”:
  - The secret name is wrong (case-sensitive) or was set in the wrong repo/environment. Confirm repo is `junhengz/auto-company` and secrets are repository-level Actions secrets.

## Operational Notes (CTO)
- Treat `SUPABASE_ACCESS_TOKEN` like a production credential: scope minimally, rotate on schedule, and keep ownership clear.
- Prefer forced, deterministic automation (`--set-all --non-interactive`) for incident-like unblock work; then later tighten verification permissions for routine checks.
