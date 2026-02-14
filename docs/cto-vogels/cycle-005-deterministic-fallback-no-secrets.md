# Cycle 005: Deterministic Fallback Evidence (No Supabase Provisioning Secrets)

## Objective
Keep producing machine-checkable Cycle 005 artifacts even when Supabase provisioning (Management API) secrets are unavailable.

This path verifies the SQL bundle against a vanilla `postgres:15` service container in GitHub Actions. It does **not** provision Supabase and does **not** require:

- `SUPABASE_ACCESS_TOKEN`
- `SUPABASE_ORG_SLUG`
- `SUPABASE_DB_PASSWORD`

## Why This Works (Reliability Lens)
- Everything fails: secrets are a frequent operational dependency that may be missing in forks, new repos, or during incident response.
- Decouple concerns: "schema bundle applies + verifies" is a prerequisite that can be validated independently of "managed Supabase project provisioning".
- Deterministic evidence: a pinned Postgres image + known SQL bundle yields reproducible verification JSON.

## Mechanism
Workflow (no secrets required):
- `.github/workflows/cycle-005-postgres-service-apply-verify.yml`

Role-owned wrapper (stores evidence under `docs/cto-vogels/`):
- `scripts/devops/run-cycle-005-cto-vogels-fallback-evidence.sh`

## Run It
Dispatch + watch + download artifacts into `docs/cto-vogels/`:

```bash
scripts/devops/run-cycle-005-cto-vogels-fallback-evidence.sh \
  --repo junhengz/auto-company
```

Download-only (given a run id):

```bash
scripts/devops/run-cycle-005-cto-vogels-fallback-evidence.sh \
  --repo junhengz/auto-company \
  --run-id <RUN_ID>
```

## Evidence Contract (Machine-Checkable)
Primary gate file:
- `docs/cto-vogels/cycle-005/postgres-service-apply-verify/latest/report.json`

Verification payload (from the workflow artifact):
- `docs/cto-vogels/cycle-005/postgres-service-apply-verify/latest/supabase-verify.json`

Minimal acceptance check:

```bash
jq -e '.result.ok == true' docs/cto-vogels/cycle-005/postgres-service-apply-verify/latest/report.json
```

## What This Does Not Prove
This fallback does not prove Supabase Management API provisioning works (that still requires secrets and org permissions). It proves the shipped SQL bundle is internally consistent and applies cleanly to Postgres.

