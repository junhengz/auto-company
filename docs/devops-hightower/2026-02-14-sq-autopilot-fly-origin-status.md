# Status: SQ Autopilot Hosted Origin (Fly) - 2026-02-14

## Current Infra Status

- Target hosted runtime origin: `https://auto-company-sq-autopilot.fly.dev`
- GitHub repo variables (repo: `junhengz/auto-company`)
  - `HOSTED_WORKFLOW_BASE_URL` = `https://auto-company-sq-autopilot.fly.dev`
  - `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` = `https://auto-company-sq-autopilot.fly.dev`
- Runtime DNS/health
  - `curl https://auto-company-sq-autopilot.fly.dev/api/workflow/env-health` fails with NXDOMAIN (`Could not resolve host`)
  - Conclusion: Fly app is not created/deployed (or DNS not established yet).

## Workflow Rerun Evidence

Reran GitHub Actions workflow `cycle-005-hosted-persistence-evidence` with:

- `local_runtime=false`
- `preflight_require_supabase_health=true`

Result:

- Run: `https://github.com/junhengz/auto-company/actions/runs/22013244552`
- Conclusion: `failure`
- Failure reason: BASE_URL selection failed because the only candidate (`https://auto-company-sq-autopilot.fly.dev`) is not resolvable (HTTP `000`).

## Blockers

1. Fly auth is not configured in this operator environment:
   - `~/.fly/bin/flyctl auth whoami` returns `No access token available`.
   - Need `FLY_API_TOKEN` (recommended, non-interactive) or interactive `flyctl auth login`.
2. Strict preflight requires Supabase env on the hosted runtime:
   - Must set Fly secrets: `NEXT_PUBLIC_SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`.
   - Additionally, Supabase must be provisioned + schema/seed applied for `supabase-health` to pass.

