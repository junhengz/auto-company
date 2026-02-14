Date: 2026-02-14
Role: qa-bach

# Status: Fly Hosted Origin + Cycle 005 Evidence

## What Was Needed

- A stable hosted runtime origin for the workflow API:
  - Target: `https://auto-company-sq-autopilot.fly.dev`
  - Backed by Fly app `auto-company-sq-autopilot`
- `HOSTED_WORKFLOW_BASE_URL` repo variable must be set to that origin
- GitHub Actions run of `cycle-005-hosted-persistence-evidence` with:
  - `local_runtime=false`
  - `preflight_require_supabase_health=true`
  - (for actual evidence) `preflight_only=false`

## What I Verified Locally (2026-02-14)

- `flyctl` was not installed initially; installed to `~/.fly/bin/flyctl`.
- Current DNS state for intended origin:
  - `curl -I https://auto-company-sq-autopilot.fly.dev` -> `Could not resolve host` (NXDOMAIN / not deployed yet).
- Fly CLI auth state:
  - `flyctl auth whoami` -> `No access token available` (not logged in; no `FLY_API_TOKEN` present in env).
- GitHub permissions in this environment:
  - `nicepkg/auto-company`: `READ` (cannot set variables / dispatch workflows)
  - `junhengz/auto-company`: `ADMIN` (usable for workflow reruns while upstream access is pending)

## Repo Changes Delivered

- `scripts/devops/run-cycle-005-hosted-persistence-evidence.sh`
  - Added `--full` flag to dispatch `preflight_only=false` for an actual evidence run.
- `scripts/devops/deploy-sq-autopilot-fly-and-preflight.sh`
  - Default GitHub repo target now infers from `gh repo view` (instead of hardcoding a fork).
- `docs/qa/cycle-005-fly-hosted-runtime-deploy-runbook-qa-bach-2026-02-14.md`
  - Concrete commands to deploy to Fly, probe env-health/supabase-health, and dispatch the full Cycle 005 evidence workflow.

## Blockers (Why Deploy + Rerun Could Not Be Completed Here)

1. Missing Fly credentials in this environment:
   - Need: `FLY_API_TOKEN` (preferred) or an interactive `flyctl auth login`.
2. Insufficient GitHub permissions on upstream `nicepkg/auto-company`:
   - Need: `>= WRITE` to set `HOSTED_WORKFLOW_BASE_URL` and dispatch `cycle-005-hosted-persistence-evidence`.
3. For `preflight_require_supabase_health=true` to pass:
   - Need Fly secrets set to real values:
     - `NEXT_PUBLIC_SUPABASE_URL`
     - `SUPABASE_SERVICE_ROLE_KEY`
   - And the Supabase project referenced by `NEXT_PUBLIC_SUPABASE_URL` must have the SQL bundle applied.

## Risk Notes (QA View)

- Setting placeholder Supabase env values will make `env-health` look green, but `supabase-health` will fail, and so will any evidence run that requires DB persistence.
- A full evidence run (`preflight_only=false`) writes evidence artifacts and opens/updates a PR; do this only after `env-health` and `supabase-health` are both green on the hosted origin.

## Next Action

Export `FLY_API_TOKEN`, `NEXT_PUBLIC_SUPABASE_URL`, and `SUPABASE_SERVICE_ROLE_KEY`, then run:

```bash
./scripts/devops/deploy-sq-autopilot-fly-and-preflight.sh \
  --repo junhengz/auto-company \
  --preflight-require-supabase-health true

./scripts/devops/run-cycle-005-hosted-persistence-evidence.sh \
  --repo junhengz/auto-company \
  --full \
  --preflight-require-supabase-health true
```
