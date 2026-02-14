# Cycle 003: Hosted Runtime Origin Status - 2026-02-14

## Current Status
- Desired stable origin (Fly): `https://auto-company-sq-autopilot.fly.dev`
- DNS: NXDOMAIN (app not deployed / not created)

## Fork Baseline (What Works Today)
Repo: `junhengz/auto-company`
- Preflight-only can be run green using `local_runtime=true` in `cycle-005-hosted-persistence-evidence` (run `22013120396` succeeded).

## Operator Commands
Set vars + run preflight (local runtime):

```bash
scripts/devops/gh-set-hosted-base-url-and-run-preflight.sh \
  --repo junhengz/auto-company \
  --run --local-runtime --require-supabase-health false
```

After a real hosted origin exists (and Supabase is provisioned), run hosted preflight:

```bash
scripts/devops/gh-set-hosted-base-url-and-run-preflight.sh \
  --repo junhengz/auto-company \
  --base-url https://auto-company-sq-autopilot.fly.dev \
  --set-canonical --set-candidates \
  --run --require-supabase-health true
```

## Next Action
Acquire `FLY_API_TOKEN` (and/or install `flyctl`) and deploy `projects/security-questionnaire-autopilot` to Fly with app name `auto-company-sq-autopilot`, then re-run hosted preflight.

