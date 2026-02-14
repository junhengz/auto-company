# Cycle 005: Supabase Provision + Apply + Verify Unblock (GHA)

Date: 2026-02-14  
Owner: qa-bach  
Repo: `junhengz/auto-company`

## Goal (Decisive)

Get a GitHub Actions run that produces an artifact `supabase-verify.json` with:

```bash
jq -e '.ok == true' docs/devops/evidence/supabase-verify-run-<RUN_ID>.json
```

## Current State (Machine-Checkable Evidence)

The workflow is currently blocked because required GitHub Actions secrets are missing in `junhengz/auto-company`:

- DevOps evidence (secrets check): `docs/devops/evidence/actions-secrets-check-junhengz_auto-company-20260214T033157Z-402190-21478.json`
- QA evidence (secrets check): `docs/qa-bach/cycle-018-gh-secrets-supabase-provision-junhengz_auto-company-20260214T033548Z-403937-12303.json`

Most recent captured workflow evidence shows the fallback `supabase-verify.json` (not a successful apply/verify):

- `docs/devops/evidence/supabase-verify-run-22010216881.json` (expected `.ok == false`, reason `workflow_failed_before_apply`)

## Blocker (What Must Change)

Set these GitHub Actions repo secrets in `junhengz/auto-company`:

- `SUPABASE_ACCESS_TOKEN`
- `SUPABASE_ORG_SLUG`
- `SUPABASE_DB_PASSWORD`

Until those exist, the dispatch workflow will fail early during "Provision Supabase project" and only upload a fallback `supabase-verify.json` with `ok=false`.

## Fastest Operator Path (Non-Interactive, Evidence-Producing)

1. Set secret values in your shell (do not commit these):

```bash
export GH_TOKEN="github_pat_..."              # needs repo+workflow permissions
export SUPABASE_ACCESS_TOKEN="..."           # Supabase PAT with org/project mgmt access
export SUPABASE_ORG_SLUG="your-org-slug"
export SUPABASE_DB_PASSWORD="..."            # used to set the project's DB password / build DB URL
```

2. Set any missing repo secrets (writes evidence to `docs/qa-bach/`):

```bash
scripts/devops/gh-ensure-supabase-provision-secrets.sh \
  --repo junhengz/auto-company \
  --set-missing \
  --non-interactive
```

3. Dispatch + watch + download artifacts (writes evidence to `docs/devops/evidence/`):

```bash
scripts/devops/run-cycle-005-supabase-provision-apply-verify.sh --repo junhengz/auto-company
```

4. Assert success (machine-checkable):

```bash
jq -e '.ok == true' docs/devops/evidence/supabase-verify-run-<RUN_ID>.json
```

## QA Pass/Fail Heuristic

Pass (sufficient for Cycle 005 unblock):

- GitHub Actions run concludes `success`.
- Extracted `docs/devops/evidence/supabase-verify-run-<RUN_ID>.json` exists and `jq -e '.ok == true'` succeeds.

Fail (still blocked / not unblocked):

- Any missing secret evidence persists.
- `supabase-verify` shows `ok=false` and `reason=workflow_failed_before_apply`.
- Artifact download evidence (`docs/devops/evidence/artifact-fetch-*.json`) indicates `supabase-verify.json` missing.

## Minimal Operator-Confusion Fixes (Implemented)

To reduce interactive blocking / misleading behavior in the operator wrapper:

- Updated `scripts/devops/run-cycle-005-supabase-provision-apply-verify.sh`:
  - `--no-watch` now means "dispatch only" and does not attempt artifact download.
  - When secrets are missing, it prints a concrete pointer to `scripts/devops/gh-ensure-supabase-provision-secrets.sh`.
  - When `--skip-secrets-check` is used, it warns that a fallback `supabase-verify.json` with `ok=false` is expected if secrets are absent.

## Next Action

Provide real values for `SUPABASE_ACCESS_TOKEN`, `SUPABASE_ORG_SLUG`, `SUPABASE_DB_PASSWORD` in `junhengz/auto-company` repo secrets (via the script above), then re-run:

```bash
scripts/devops/run-cycle-005-supabase-provision-apply-verify.sh --repo junhengz/auto-company
```
