# Cycle 005 Hosted Persistence Evidence: Local Runtime Preflight (Run 22011975846)

This is a successful `preflight_only=true` run using `local_runtime=true` (ephemeral Next.js runtime inside the GitHub Actions job). It validates the runtime contract for:

- `GET /api/workflow/env-health` returns `200` JSON with `ok=true` and both env booleans `true`.

It does **not** prove an externally hosted production origin exists, and it does **not** run Supabase persistence checks (`preflight_require_supabase_health=false`).

## Run Reference
- Repo: `junhengz/auto-company`
- Workflow: `cycle-005-hosted-persistence-evidence`
- Run: `22011975846`
- Run URL: see `run.json` (`url` field)

## Downloaded Artifacts
Artifacts are downloaded under this directory:

- `cycle-005-hosted-base-url-probe/`
- `cycle-005-hosted-preflight/`

## Next Step
Create a real hosted origin (Vercel recommended) for `projects/security-questionnaire-autopilot`, then set repo variable `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` to 2-4 real origins and re-run preflight with `local_runtime=false`.

