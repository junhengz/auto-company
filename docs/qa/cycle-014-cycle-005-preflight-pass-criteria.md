# Cycle 014 QA: Cycle 005 Preflight Pass Criteria (Hosted Persistence Evidence)

Date: 2026-02-14

Target repo: `junhengz/security-questionnaire-autopilot`

Scope: define what “green preflight” means for `.github/workflows/cycle-005-hosted-persistence-evidence.yml` with `preflight_only=true` (and `skip_sql_apply=true`, which is required in preflight-only mode).

## Preflight Inputs That Must Hold

- `preflight_only=true`
- `skip_sql_apply=true`
- BASE_URL selection succeeds from:
  - workflow input `base_url`/`base_url_candidates`, or
  - repo variable `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` (recommended), or
  - discovery (hosting API / GitHub Deployments) if configured

## Hosted Runtime Endpoints That Must Pass

1. `GET <BASE_URL>/api/workflow/env-health`
   - HTTP `200`
   - JSON body includes:
     - `.ok == true`
     - `.env.NEXT_PUBLIC_SUPABASE_URL == true`
     - `.env.SUPABASE_SERVICE_ROLE_KEY == true`

2. `GET <BASE_URL>/api/workflow/supabase-health?requireSeed=1&requirePilotDeals=1`
   - HTTP `200`
   - JSON body includes:
     - `.ok == true`
     - `.schema.actual_schema_bundle_id == .schema.expected_schema_bundle_id`
     - `.seed.present == true`
     - `.tables.workflow_runs == true`
     - `.tables.workflow_events == true`
     - `.tables.pilot_deals == true`

## Failure Interpretation (Fast Triage)

- `env-health` is HTML / not JSON / 404:
  - Wrong BASE_URL (marketing/static site, wrong service, or wrong domain).
- `env-health ok=true` but env booleans are `false`:
  - Correct runtime, but hosting provider env vars are missing.
  - Fix on provider, then redeploy.
- `supabase-health` returns 400:
  - Hosted runtime is missing `NEXT_PUBLIC_SUPABASE_URL` or `SUPABASE_SERVICE_ROLE_KEY`.
- `supabase-health` returns 500 with `workflow_app_meta not queryable` or “schema bundle mismatch”:
  - Supabase schema/seed not applied (or applied to the wrong project).

## Artifacts Expected From A Green Preflight Run

GitHub Actions artifact: `cycle-005-hosted-preflight`
- `preflight/base-url-candidates.txt`
- `preflight/base-url-source.txt`
- `preflight/base-url-probe.txt`
- `preflight/env-health.json` (and `preflight/env-health.after-redeploy.json` if auto-fix ran)
- `preflight/supabase-health.json`

## Next Action

Once a deployed BASE_URL exists, validate the two endpoints above manually with `curl` before dispatching the GitHub Action; then run `cycle-005-hosted-persistence-evidence` with `preflight_only=true` until artifacts match this document.

