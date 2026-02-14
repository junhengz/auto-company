# Cycle 030: Fly Hosted Origin + Cycle 005 Rerun (2026-02-14)

## Objective

Establish a single stable hosted workflow runtime origin for `projects/security-questionnaire-autopilot` on Fly.io (app: `auto-company-sq-autopilot`) so the canonical repo variable `HOSTED_WORKFLOW_BASE_URL` is *real and reachable*, then rerun `cycle-005-hosted-persistence-evidence` with:

- `local_runtime=false`
- `preflight_require_supabase_health=true`

## Current Status (Observed 2026-02-14)

- GitHub repo: `junhengz/auto-company`
  - `HOSTED_WORKFLOW_BASE_URL=https://auto-company-sq-autopilot.fly.dev`
  - `HOSTED_WORKFLOW_BASE_URL_CANDIDATES=https://auto-company-sq-autopilot.fly.dev`
- Public DNS for `auto-company-sq-autopilot.fly.dev` does **not** resolve (`curl: (6) Could not resolve host`), so the configured canonical origin is currently unusable.
- Local Fly CLI is present at `~/.fly/bin/flyctl` but Fly auth is missing (`flyctl auth whoami` => "No access token available").
- This environment does not have Supabase credentials exported (`NEXT_PUBLIC_SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`).

## Repo Changes Made

- Tightened `scripts/devops/deploy-sq-autopilot-fly-and-preflight.sh` so `--preflight-require-supabase-health=true` requires real Supabase env vars (no placeholders). This prevents “green-ish” env-health while supabase-health is guaranteed to fail.
  - File: `scripts/devops/deploy-sq-autopilot-fly-and-preflight.sh`

## Runbook (Operator)

### 1) Prereqs: Credentials (One-Time)

- Fly:
  - Obtain a Fly access token with permission to manage the Fly org/app.
  - Provide it as `FLY_API_TOKEN` in the shell running the deploy.
- Supabase (required for strict preflight):
  - `NEXT_PUBLIC_SUPABASE_URL="https://<project-ref>.supabase.co"`
  - `SUPABASE_SERVICE_ROLE_KEY="<service-role-key>"`
  - Ensure the Supabase schema/seed expected by `GET /api/workflow/supabase-health?requireSeed=1&requirePilotDeals=1` is applied.

### 2) Deploy to Fly and Persist Canonical BASE_URL

This deploys `projects/security-questionnaire-autopilot`, ensures the Fly volume mount for `/app/runs`, probes hosted `env-health`, then persists `HOSTED_WORKFLOW_BASE_URL` into `junhengz/auto-company`.

```bash
cd /home/zjohn/autocomp/auto-company

export PATH="$HOME/.fly/bin:$PATH"
export FLY_API_TOKEN="..."                       # required
export NEXT_PUBLIC_SUPABASE_URL="https://...supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="..."

scripts/devops/deploy-sq-autopilot-fly-and-preflight.sh \
  --app auto-company-sq-autopilot \
  --region iad \
  --repo junhengz/auto-company \
  --preflight-require-supabase-health true
```

Expected results:

- Fly app exists with volume `runs` mounted at `/app/runs` (single-machine `immediate` deploy strategy).
- `HOSTED_WORKFLOW_BASE_URL` in `junhengz/auto-company` is set to `https://auto-company-sq-autopilot.fly.dev`.
- Cycle 005 preflight-only run is dispatched (hosted mode; no local runtime).

### 3) Verify the Hosted Runtime (Outside CI)

```bash
curl -sS -m 20 https://auto-company-sq-autopilot.fly.dev/api/workflow/env-health
curl -sS -m 20 "https://auto-company-sq-autopilot.fly.dev/api/workflow/supabase-health?requireSeed=1&requirePilotDeals=1"
```

### 4) Rerun Cycle 005 With Required Inputs

Option A (wrapper):

```bash
cd /home/zjohn/autocomp/auto-company

scripts/devops/run-cycle-005-hosted-persistence-evidence.sh \
  --repo junhengz/auto-company \
  --preflight-only \
  --preflight-require-supabase-health true
```

Option B (raw `gh`):

```bash
gh workflow run cycle-005-hosted-persistence-evidence.yml \
  -R junhengz/auto-company \
  -f local_runtime=false \
  -f preflight_only=true \
  -f preflight_require_supabase_health=true
```

Track:

```bash
gh run list -R junhengz/auto-company --workflow cycle-005-hosted-persistence-evidence.yml -L 5
```

## Failure Modes / Triage

- `flyctl auth whoami` fails:
  - Provide `FLY_API_TOKEN` (preferred for non-interactive ops), or login interactively.
- `auto-company-sq-autopilot.fly.dev` still NXDOMAIN after deploy:
  - Confirm `fly apps show auto-company-sq-autopilot` and that at least one Machine is running.
  - Confirm the app has a `fly.dev` hostname/cert provisioned (Fly generally does this automatically after first deploy).
- `env-health` ok but Cycle 005 fails on supabase-health:
  - The hosted runtime likely has wrong/missing Supabase env vars, or the Supabase schema/seed is not applied.
  - Fix by updating Fly secrets and redeploying.

## Next Action

Provide `FLY_API_TOKEN`, `NEXT_PUBLIC_SUPABASE_URL`, and `SUPABASE_SERVICE_ROLE_KEY`, then run the deploy command in this runbook to establish the real `https://auto-company-sq-autopilot.fly.dev` origin and rerun Cycle 005 with strict Supabase health.

