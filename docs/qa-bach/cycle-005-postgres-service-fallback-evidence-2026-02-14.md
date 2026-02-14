# Cycle 005: Fallback Evidence (Postgres Service Apply/Verify, No Supabase Provisioning Secrets)

Date: 2026-02-14

## Goal

Unblock Cycle 005 progress by producing machine-checkable evidence that the Cycle 005 SQL bundle applies cleanly and verifies against a vanilla Postgres database, without requiring Supabase Management API provisioning secrets (`SUPABASE_ACCESS_TOKEN`, `SUPABASE_ORG_SLUG`, `SUPABASE_DB_PASSWORD`).

## Evidence Run (GitHub Actions)

Workflow:
- `.github/workflows/cycle-005-postgres-service-apply-verify.yml`

Repo/run:
- repo: `junhengz/auto-company`
- run id: `22011127973`

Result:
- `ok: true` in the extracted `supabase-verify` JSON.

Primary machine-checkable artifact (pointer):
- `docs/qa-bach/cycle-005/postgres-service-apply-verify/latest/run.json`

Primary machine-checkable artifact (verification JSON):
- `docs/qa-bach/cycle-005/postgres-service-apply-verify/latest/supabase-verify.json`

Raw per-run evidence:
- `docs/qa-bach/cycle-005/postgres-service-apply-verify/evidence/supabase-verify-run-22011127973.json`
- `docs/qa-bach/cycle-005/postgres-service-apply-verify/evidence/artifact-fetch-20260214T042649Z-run-22011127973.json`
- `docs/qa-bach/cycle-005/postgres-service-apply-verify/workflow-dispatch-20260214T042610Z.json`

## How To Re-run (Deterministic Fallback Path)

Dispatch + watch + download artifacts (no Supabase provisioning secrets required):

```bash
scripts/devops/run-cycle-005-fallback-postgres-service-evidence.sh \
  --repo junhengz/auto-company \
  --out-dir docs/qa-bach/cycle-005/postgres-service-apply-verify
```

Quick check:

```bash
jq -e '.ok == true' docs/qa-bach/cycle-005/postgres-service-apply-verify/latest/supabase-verify.json
```

## Quality Risks / Limitations (Context-Driven)

This fallback path reduces the highest-risk blocker (provisioning secrets) but it is not a full substitute for Supabase-hosted validation:

- Applies to vanilla Postgres (`postgres:15`), not a real Supabase project; Supabase-specific behavior (extensions, auth schema, RLS policies, edge cases) is not fully covered.
- Verifies DB schema/seed expectations only; it does not validate hosted runtime configuration or end-to-end persistence from the deployed Next.js API.

