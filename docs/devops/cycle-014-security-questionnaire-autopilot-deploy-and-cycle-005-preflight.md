# Cycle 014 DevOps Runbook: Deploy Product Repo + Run Cycle 005 Preflight

Date: 2026-02-14

Repo (product):
- GitHub: `junhengz/security-questionnaire-autopilot`
- Local: `/home/zjohn/autocomp/security-questionnaire-autopilot`

Goal:
1. Deploy the Next.js hosted workflow runtime (must serve `/api/workflow/*`).
2. Ensure hosted runtime has Supabase env configured.
3. Run GitHub Actions workflow `cycle-005-hosted-persistence-evidence` with `preflight_only=true` until green.
4. Re-run with `preflight_only=false` to generate the evidence PR.

## Current Blockers (Observed In This Workspace)

- No existing GitHub Deployments metadata for `junhengz/security-questionnaire-autopilot` (candidate discovery via Deployments returns empty).
- No hosted BASE_URL candidates are known.
- No GitHub secrets/vars are configured yet (at minimum, Cycle 005 needs either a deployed BASE_URL with Supabase configured, or automation tokens to set it up).

## Credential Boundaries (Do Not Mix These Up)

Hosted runtime env vars (set on the hosting provider, not GitHub):
- `NEXT_PUBLIC_SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

GitHub Actions secrets (repo secrets):
- `NEXT_PUBLIC_SUPABASE_URL` (optional but required if you want CI auto-fix env sync)
- `SUPABASE_SERVICE_ROLE_KEY` (optional but required if you want CI auto-fix env sync)
- `SUPABASE_DB_URL` (required only if running SQL apply via workflow/script; NOT required for `skip_sql_apply=true` paths)
- `VERCEL_TOKEN` (optional, enables CI auto-fix + runtime env sync on Vercel)
- `CLOUDFLARE_API_TOKEN` (optional, enables CI auto-fix + runtime env sync on Cloudflare Pages)

GitHub Actions variables (repo variables):
- `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` (recommended, 2-4 origins; makes Cycle 005 deterministic)
- For Vercel automation: `VERCEL_PROJECT_ID` or `VERCEL_PROJECT` (and optionally `VERCEL_TEAM_ID` / `VERCEL_TEAM_SLUG`)
- For Cloudflare Pages automation: `CLOUDFLARE_ACCOUNT_ID`, `CF_PAGES_PROJECT` (and optional deploy/build hook secret)

## Step 1: Provision Supabase And Apply Schema/Seed

Cycle 005 preflight calls:
- `GET <BASE_URL>/api/workflow/supabase-health?requireSeed=1&requirePilotDeals=1`

That endpoint requires:
- Supabase env vars set on hosted runtime
- Schema bundle applied (tables + `workflow_app_meta.schema_bundle_id`)
- Seed row present (`workflow_runs.run_id = pilot-001-live-2026-02-13`)

Fast paths:
1. Apply via Supabase Dashboard SQL Editor:
   - SQL bundle: `projects/security-questionnaire-autopilot/supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql`
2. Or apply via GitHub Action:
   - Workflow: `.github/workflows/cycle-005-supabase-apply.yml`
   - Requires secret: `SUPABASE_DB_URL`

## Step 2: Deploy Hosted Runtime

Minimum acceptance for a correct BASE_URL:
- `curl -sS <BASE_URL>/api/workflow/env-health | jq -e '.ok == true'`

And for Cycle 005 runs:
- `jq -e '.env.NEXT_PUBLIC_SUPABASE_URL == true and .env.SUPABASE_SERVICE_ROLE_KEY == true'`

Pick one hosting:
1. Vercel (recommended for Next.js App Router)
2. Cloudflare Pages (supported by scripts/workflows, but still requires manual setup + redeploy hook to be fully automated)

## Step 3: Set Repo Variable For Deterministic BASE_URL Selection

Set `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` once (2-4 origins):

```bash
gh variable set HOSTED_WORKFLOW_BASE_URL_CANDIDATES \
  -R junhengz/security-questionnaire-autopilot \
  --body "https://<candidate-1> https://<candidate-2>"
```

## Step 4: (Optional) Enable CI Runtime Env Sync

If you want CI to fix missing hosted env vars automatically, set these secrets:
- `NEXT_PUBLIC_SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- plus provider token + ids (`VERCEL_TOKEN` + `VERCEL_PROJECT_ID|VERCEL_PROJECT`, or `CLOUDFLARE_API_TOKEN` + `CLOUDFLARE_ACCOUNT_ID` + `CF_PAGES_PROJECT`)

Then you can dispatch:
- `.github/workflows/cycle-005-hosted-runtime-env-sync.yml`

## Step 5: Run Cycle 005 Preflight (Must Be Green Before Evidence)

Dispatch preflight:

```bash
cd /home/zjohn/autocomp/security-questionnaire-autopilot
./scripts/devops/run-cycle-005-hosted-persistence-evidence.sh \
  --repo junhengz/security-questionnaire-autopilot \
  --preflight-only
```

Expected: green run + artifact `cycle-005-hosted-preflight` containing:
- `preflight/env-health.json` (and possibly `env-health.after-redeploy.json`)
- `preflight/supabase-health.json` with `.ok == true`

Then run evidence (creates/updates PR branch `cycle-005-hosted-persistence-evidence`):

```bash
./scripts/devops/run-cycle-005-hosted-persistence-evidence.sh \
  --repo junhengz/security-questionnaire-autopilot
```

## Next Action

Create a Supabase project and provide its values (URL, service role key, DB URL) and choose a hosting provider (Vercel or Cloudflare Pages); once a real deployed BASE_URL exists, set `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` and dispatch Cycle 005 `--preflight-only`.
