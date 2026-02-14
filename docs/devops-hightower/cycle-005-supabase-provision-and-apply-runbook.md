# Cycle 005: Provision Supabase + Apply Bundle (Hosted Preflight Must Pass)

Objective: make `GET <BASE_URL>/api/workflow/supabase-health?requireSeed=1&requirePilotDeals=1` return `200` with `{ ok: true }` during Cycle 005 preflight.

What the health check enforces (current contract):
- Schema identity: `public.workflow_app_meta.meta_key='schema_bundle_id'` must equal `20260213_cycle003_hosted_workflow`
- Seed presence: `public.workflow_runs.run_id='pilot-001-live-2026-02-13'` must exist
- Tables must be queryable: `workflow_app_meta`, `workflow_runs`, `workflow_events`, `pilot_deals`

Bundle to apply (migration + seed; paste-ready):
- `projects/security-questionnaire-autopilot/supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql`

## Required Secrets / Vars (Names Only)

Hosted runtime (set on the deployment platform for the Next.js app serving `/api/workflow/*`):
- `NEXT_PUBLIC_SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

SQL apply (needed only if you want CI/local to apply the SQL bundle; Dashboard SQL Editor does not need this):
- `SUPABASE_DB_URL`

Optional (only if automating provider env sync/redeploy via CI scripts):
- `VERCEL_TOKEN` and `VERCEL_PROJECT_ID` (or `VERCEL_PROJECT`)
- `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`, `CF_PAGES_PROJECT`

## Provision Supabase Project (Manual, Most Reliable Without CLI)

1. Supabase Dashboard: create/select the target project for hosted persistence.
2. Record (do not commit):
   - project URL into `NEXT_PUBLIC_SUPABASE_URL`
   - Service Role key into `SUPABASE_SERVICE_ROLE_KEY`
   - DB connection string into `SUPABASE_DB_URL` (only if using CI/local SQL apply)

Safety check: this project must be the one your hosted runtime points at (the value of `NEXT_PUBLIC_SUPABASE_URL` on the deployed runtime).

## Apply Schema + Seed (Choose Exactly One Path)

### Path A: Supabase Dashboard SQL Editor (Recommended)

1. Supabase Dashboard -> SQL Editor.
2. Paste the entire bundle and run once:
   - `projects/security-questionnaire-autopilot/supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql`
3. Verify in the SQL editor output (the bundle ends with verification `select`s).

Optional stale-bundle guard (run locally from this repo):

```bash
cd /home/zjohn/autocomp/auto-company/projects/security-questionnaire-autopilot
node scripts/verify-dashboard-sql-bundle.mjs \
  --bundle supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql
```

### Path B: GitHub Actions SQL Apply (Auditable + Deterministic)

Pre-req: set repo secret `SUPABASE_DB_URL`.

Dispatch:
- Workflow: `.github/workflows/cycle-005-supabase-apply.yml`
- Input `sql_bundle` default is already correct.

CLI dispatch example:

```bash
gh workflow run cycle-005-supabase-apply \
  -f sql_bundle="projects/security-questionnaire-autopilot/supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql"
```

### Path C: Local Apply (Node + pg; No `psql`, No Supabase CLI)

Pre-req: export `SUPABASE_DB_URL` in a short-lived subshell.

```bash
cd /home/zjohn/autocomp/auto-company/projects/security-questionnaire-autopilot
( export SUPABASE_DB_URL="..."; ./scripts/apply-supabase-bundle.sh )
```

## Configure Hosted Runtime Env Vars (Required For Preflight)

Set these on the hosting provider for the deployed Next.js app:
- `NEXT_PUBLIC_SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

Then redeploy.

Probe:

```bash
curl -sS "<BASE_URL>/api/workflow/env-health" | jq .
```

Pass criteria:
- `.ok == true`
- `.env.NEXT_PUBLIC_SUPABASE_URL == true`
- `.env.SUPABASE_SERVICE_ROLE_KEY == true`

## Verify Cycle 005 Preflight Gate

```bash
curl -sS "<BASE_URL>/api/workflow/supabase-health?requireSeed=1&requirePilotDeals=1" | jq .
```

Expected:
- `.ok == true`
- `.schema.actual_schema_bundle_id == "20260213_cycle003_hosted_workflow"`
- `.seed.present == true` with `.seed.run_id == "pilot-001-live-2026-02-13"`

## Rollback / Safety Notes

Safety:
- The main failure mode is applying the bundle to the wrong Supabase project. Always confirm the hosted runtime `NEXT_PUBLIC_SUPABASE_URL` points at the same project you are editing.
- The SQL bundle is designed to be re-runnable (uses `if not exists` + upserts), so re-applying to the correct project is usually safe.

Rollback (if you must remove this schema from a project):
- Drop in reverse dependency order:
  - `drop table if exists public.workflow_events;`
  - `drop table if exists public.pilot_deals;`
  - `drop table if exists public.workflow_runs;`
  - `drop table if exists public.workflow_app_meta;`

