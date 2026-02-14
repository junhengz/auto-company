# Cycle 032: Deploy SQ Autopilot to Fly + Re-run Cycle 005 Hosted Preflight (Strict)

Date: 2026-02-14
Owner: operations-pg

## Stage Diagnosis

Pre-PMF. This is "do things that don't scale" ops: get one stable hosted runtime origin and one stable Supabase project so the evidence loop can run without heroics.

## Goal (Concrete)

1. `projects/security-questionnaire-autopilot` is deployed to Fly app `auto-company-sq-autopilot`.
2. `HOSTED_WORKFLOW_BASE_URL` points at the real origin `https://auto-company-sq-autopilot.fly.dev` and it is reachable.
3. GitHub workflow `cycle-005-hosted-persistence-evidence` is re-run with:
   - `local_runtime=false`
   - `preflight_require_supabase_health=true`

Success signal:
- `GET https://auto-company-sq-autopilot.fly.dev/api/workflow/env-health` returns `200` with `.ok=true` and both Supabase env booleans `true`.
- `GET https://auto-company-sq-autopilot.fly.dev/api/workflow/supabase-health?requireSeed=1&requirePilotDeals=1` returns `200` with `.ok=true`.
- A dispatched Cycle 005 preflight run uploads `preflight/env-health.json` and `preflight/supabase-health.json` with `.ok=true`.

## Current Status (This Workspace)

- Fly CLI: installed to `~/.fly/bin/flyctl`.
- GitHub: `junhengz/auto-company` permission is `ADMIN` (workflow dispatch and variables are allowed).
- Repo variables on `junhengz/auto-company` are already set:
  - `HOSTED_WORKFLOW_BASE_URL=https://auto-company-sq-autopilot.fly.dev`
  - `HOSTED_WORKFLOW_BASE_URL_CANDIDATES=https://auto-company-sq-autopilot.fly.dev`
- Blocker: Fly auth is not configured in this shell (no `FLY_API_TOKEN`), so we cannot create/deploy the Fly app here yet.
- Blocker (strict preflight): Supabase runtime env values are not present in this shell (`NEXT_PUBLIC_SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`).

As of 2026-02-14, `auto-company-sq-autopilot.fly.dev` does not resolve (NXDOMAIN) until the Fly app is created/deployed.

Most recent strict preflight attempt (failed due to NXDOMAIN):
- `junhengz/auto-company` run `22013244552` at `2026-02-14T07:09:10Z`
- failure: could not resolve `auto-company-sq-autopilot.fly.dev` when probing `/api/workflow/env-health`

## Repo Artifacts Added/Updated

- `scripts/devops/install-flyctl.sh`: deterministic Fly CLI install helper.
- `scripts/devops/deploy-sq-autopilot-fly-and-preflight.sh`: added `--install-flyctl`, improved retry/formatting, and clarified strict Supabase env behavior.
- `Makefile`: added targets:
  - `make sq-autopilot-fly-deploy`
  - `make sq-autopilot-fly-deploy-and-preflight`

## Execution (Maintainer Shell)

### 1) Provide Required Credentials (Names Only)

- Fly:
  - `FLY_API_TOKEN` (personal access token)
- Supabase (must match the provisioned + seeded project used for Cycle 005):
  - `NEXT_PUBLIC_SUPABASE_URL`
  - `SUPABASE_SERVICE_ROLE_KEY`

### 2) Deploy to Fly and Persist Canonical Base URL

```bash
export FLY_API_TOKEN="..."
export NEXT_PUBLIC_SUPABASE_URL="https://<project_ref>.supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="..."

cd /home/zjohn/autocomp/auto-company
make sq-autopilot-fly-deploy-and-preflight
```

What this does:
- creates Fly app + `runs` volume if missing
- sets Fly secrets (Supabase URL + service role key)
- deploys via remote builder
- probes `/api/workflow/env-health`
- persists `HOSTED_WORKFLOW_BASE_URL` and `HOSTED_WORKFLOW_BASE_URL_CANDIDATES`
- dispatches Cycle 005 preflight-only with `local_runtime=false` and `preflight_require_supabase_health=true`

### 3) (If You Want to Re-run the Workflow Manually)

```bash
./scripts/devops/run-cycle-005-hosted-persistence-evidence.sh \
  --repo junhengz/auto-company \
  --preflight-only \
  --preflight-require-supabase-health true
```

## Next Action

Get `FLY_API_TOKEN` plus the Supabase `NEXT_PUBLIC_SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` for the seeded Cycle 005 project, then run `make sq-autopilot-fly-deploy-and-preflight`.
