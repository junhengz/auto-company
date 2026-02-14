---
title: "Cycle 005: Provision Supabase + Apply SQL Bundle (Preflight Gate)"
date: 2026-02-14
owner: cto-vogels
---

## What “Healthy” Means (Contract)

Cycle 005 preflight requires the deployed hosted runtime endpoint:

`GET /api/workflow/supabase-health?requireSeed=1&requirePilotDeals=1`

to return `200` with `{ ok: true }`.

The endpoint is strict by design (prevents “wrong project / wrong schema” evidence). It checks:

1. Supabase env vars exist in the hosted runtime:
   - `NEXT_PUBLIC_SUPABASE_URL`
   - `SUPABASE_SERVICE_ROLE_KEY`
2. Schema identity matches `WORKFLOW_SCHEMA.bundleId`:
   - `public.workflow_app_meta(meta_key='schema_bundle_id').meta_value == '20260213_cycle003_hosted_workflow'`
3. Tables are queryable with representative columns:
   - `workflow_runs`, `workflow_events`, and (when `requirePilotDeals=1`) `pilot_deals`
4. Seed sentinel row exists (when `requireSeed=1`):
   - `public.workflow_runs.run_id == 'pilot-001-live-2026-02-13'`

## Constraints On This Machine (2026-02-14)

- No `supabase` CLI installed.
- No `vercel` CLI installed.
- No `SUPABASE_*` env vars present.

That means we cannot provision a Supabase project or set hosted runtime secrets from here without supplying external credentials (ideally via GitHub Actions secrets, or via interactive prompting for a one-off local run).

## Reliable Path (Minimal Moving Parts)

### Step 0: Identify The Target Hosted Runtime Base URL

You need the deployed runtime base URL:

- `BASE_URL`

Then verify runtime env visibility (no secrets leaked):

```bash
curl -sS "$BASE_URL/api/workflow/env-health" | jq .
```

Expected:

- `.ok == true`
- `.env.NEXT_PUBLIC_SUPABASE_URL == true`
- `.env.SUPABASE_SERVICE_ROLE_KEY == true`

If either env flag is `false`, fix hosted env vars first (then redeploy) before touching SQL.

### Step 1: Provision The Supabase Project (Dashboard)

Create a Supabase project in the intended org and region. Record:

- Project URL for runtime: `NEXT_PUBLIC_SUPABASE_URL`
- Service role key for runtime: `SUPABASE_SERVICE_ROLE_KEY`
- Direct DB connection string for migrations (optional but recommended for automation): `SUPABASE_DB_URL`

Note: we intentionally do not require the Supabase CLI for this flow.

### Step 1b: Provision The Supabase Project (Management API; No CLI)

Script:

- `projects/security-questionnaire-autopilot/scripts/supabase-mgmt-provision-project.sh`

Required env (names only):

- `SUPABASE_ACCESS_TOKEN`
- `SUPABASE_ORG_SLUG`
- `SUPABASE_PROJECT_NAME`
- `SUPABASE_DB_PASSWORD`

Optional env:

- `SUPABASE_REGION_SELECTION_JSON` (recommended; region selection object as JSON)

Local one-off (prompts for missing values; no secrets printed):

```bash
SUPABASE_PROMPT_FOR_MISSING=1 \
  ./projects/security-questionnaire-autopilot/scripts/supabase-mgmt-provision-project.sh
```

CI path (preferred): use GitHub Actions so no one pastes secrets into shell history.

### Step 2: Apply Schema + Seed (Choose One)

Bundle to apply (migration + seed, paste-ready):

- `projects/security-questionnaire-autopilot/supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql`

#### Option A (Most Reliable With No Local Tooling): GitHub Actions Apply

Use workflow:

- `.github/workflows/cycle-005-supabase-apply.yml`

Required GitHub Actions secret:

- `SUPABASE_DB_URL`

Dispatch with default `sql_bundle` (already points at the bundle path).

#### Option A2 (Preferred End-To-End Automation): GitHub Actions Provision + Apply + Verify

Use workflow:

- `.github/workflows/cycle-005-supabase-provision-apply-verify.yml`

Required GitHub Actions secrets (names only):

- `SUPABASE_ACCESS_TOKEN`
- `SUPABASE_ORG_SLUG`
- `SUPABASE_DB_PASSWORD`

Optional secrets:

- `SUPABASE_REGION_SELECTION_JSON`

This workflow:

1. Provisions (or reuses) a project via the Supabase Management API (no CLI).
2. Builds `SUPABASE_DB_URL` deterministically from `(project_ref + db_password)`:
   - `postgresql://postgres:<db_password>@db.<project_ref>.supabase.co:5432/postgres`
3. Applies the SQL bundle.
4. Verifies the apply with a machine-checkable signal:
   - `projects/security-questionnaire-autopilot/scripts/verify-supabase-bundle-applied.mjs`

Local helper (no secret printing; runs a command with `SUPABASE_DB_URL` set):

```bash
SUPABASE_PROJECT_REF='<project-ref>' SUPABASE_DB_PASSWORD='***' \
  ./projects/security-questionnaire-autopilot/scripts/supabase-build-db-url.sh -- \
  bash ./projects/security-questionnaire-autopilot/scripts/apply-supabase-bundle.sh
```

#### Option B (Fastest If You Have Dashboard Access): Supabase SQL Editor

1. Supabase Dashboard -> SQL Editor -> New query.
2. Paste the entire bundle file and run.

Optional safety check before pasting (ensures bundle headers match current migration/seed):

```bash
cd projects/security-questionnaire-autopilot
node scripts/verify-dashboard-sql-bundle.mjs \
  --bundle supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql
```

#### Option C (Credentialed Local Apply): Node + `pg`

Pre-req: `npm ci` in `projects/security-questionnaire-autopilot/` (because `scripts/apply-supabase-sql.mjs` depends on `pg`).

```bash
cd projects/security-questionnaire-autopilot
npm ci
SUPABASE_DB_URL='...' node scripts/apply-supabase-sql.mjs \
  supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql
```

Verification (machine-checkable; non-secret output):

```bash
cd projects/security-questionnaire-autopilot
SUPABASE_DB_URL='...' node scripts/verify-supabase-bundle-applied.mjs | jq .
```

### Step 3: Verify Health Gate (Authoritative)

```bash
curl -sS "$BASE_URL/api/workflow/supabase-health?requireSeed=1&requirePilotDeals=1" | jq .
```

Expected:

- `.ok == true`
- `.schema.actual_schema_bundle_id == "20260213_cycle003_hosted_workflow"`
- `.seed.present == true`

## Required Secrets / Vars (Names Only)

Hosted runtime (set in hosting provider secret store):

- `NEXT_PUBLIC_SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

SQL apply automation (GitHub Actions or local):

- `SUPABASE_DB_URL`

Operator input:

- `BASE_URL`

## Rollback / Safety Note

Safety properties:

- The bundle uses `create ... if not exists` and `on conflict ... do update`, so re-applying is intended to be safe and idempotent.

Rollback (destructive, last resort):

```sql
drop table if exists public.workflow_events;
drop table if exists public.pilot_deals;
drop table if exists public.workflow_runs;
drop table if exists public.workflow_app_meta;
```

Operational rollback:

1. Rotate the Supabase service role key if it was ever exposed.
2. Remove/replace `NEXT_PUBLIC_SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` on the hosted runtime.
3. Redeploy, then re-run `env-health` and `supabase-health`.

## Deterministic Unblock Checklist

1. Confirm `BASE_URL/api/workflow/env-health` reports both Supabase env vars present.
2. Apply the SQL bundle to the **same** Supabase project referenced by `NEXT_PUBLIC_SUPABASE_URL`.
3. Confirm `BASE_URL/api/workflow/supabase-health?requireSeed=1&requirePilotDeals=1` returns `{ ok:true }`.

## Next Action

Obtain access to: (1) the target Supabase Dashboard project and (2) the hosted runtime env var surface, then apply `projects/security-questionnaire-autopilot/supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql` and verify `GET $BASE_URL/api/workflow/supabase-health?requireSeed=1&requirePilotDeals=1` returns `ok=true`.
