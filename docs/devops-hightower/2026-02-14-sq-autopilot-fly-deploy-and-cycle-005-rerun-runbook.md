# Runbook: Deploy SQ Autopilot to Fly and Rerun Cycle 005 (Strict) - 2026-02-14

Goal: deploy `projects/security-questionnaire-autopilot` to a stable hosted origin (Fly app `auto-company-sq-autopilot`) so `HOSTED_WORKFLOW_BASE_URL` is a real, reachable origin, then rerun `cycle-005-hosted-persistence-evidence` with strict Supabase health.

## Prereqs

- Fly.io API token available as `FLY_API_TOKEN` (recommended for non-interactive runs).
- Supabase hosted runtime env values available:
  - `NEXT_PUBLIC_SUPABASE_URL` (e.g., `https://<project-ref>.supabase.co`)
  - `SUPABASE_SERVICE_ROLE_KEY`

## Deploy (Fly)

This repository already contains:

- Docker build: `projects/security-questionnaire-autopilot/Dockerfile`
- Fly config: `projects/security-questionnaire-autopilot/fly.toml` (includes `/app/runs` volume mount)
- Operator deploy helper: `scripts/devops/deploy-sq-autopilot-fly-and-preflight.sh`

Command (strict preflight compatible):

```bash
export FLY_API_TOKEN="..."
export NEXT_PUBLIC_SUPABASE_URL="https://<project-ref>.supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="..."

./scripts/devops/deploy-sq-autopilot-fly-and-preflight.sh \
  --app auto-company-sq-autopilot \
  --region iad \
  --repo junhengz/auto-company \
  --preflight-require-supabase-health true
```

What it does:

- Creates the Fly app (if missing) and volume `runs` (if missing).
- Sets Fly secrets (`NEXT_PUBLIC_SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`).
- Deploys with Fly remote builder.
- Probes `GET /api/workflow/env-health` for required env booleans.
- Sets GitHub repo variables:
  - `HOSTED_WORKFLOW_BASE_URL`
  - `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` (compat with older workflows)
- Dispatches `cycle-005-hosted-persistence-evidence` in preflight-only mode with `local_runtime=false`.

## Verify Hosted Origin

```bash
curl -sS -m 12 "https://auto-company-sq-autopilot.fly.dev/api/workflow/env-health" | jq .
curl -sS -m 12 "https://auto-company-sq-autopilot.fly.dev/api/workflow/supabase-health?requireSeed=1&requirePilotDeals=1" | jq .
```

## Rerun Cycle 005 (Strict)

```bash
./scripts/devops/run-cycle-005-hosted-persistence-evidence.sh \
  --repo junhengz/auto-company \
  --preflight-only \
  --preflight-require-supabase-health true
```

Track:

```bash
gh run list -R "junhengz/auto-company" --workflow "cycle-005-hosted-persistence-evidence.yml" -L 5
```

## Rollback

- Fast rollback on Fly:
  - `flyctl releases --app auto-company-sq-autopilot`
  - Redeploy a previous image/release as needed (Fly supports pinning to an image digest).

