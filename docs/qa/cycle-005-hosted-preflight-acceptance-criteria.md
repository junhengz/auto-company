# Cycle 005 QA: Hosted Preflight Acceptance Criteria (Green = Safe To Enable Autorun)

Date: 2026-02-14

Scope: Define what a "green preflight" means for the Cycle 005 hosted persistence workflow preflight-only mode, what to inspect in GitHub Actions logs/artifacts, and a checklist to run before enabling scheduled autoruns.

Applies to:
- Local operator wrapper: `scripts/devops/run-cycle-005-hosted-persistence-evidence.sh --preflight-only`
- GitHub Actions workflow: `.github/workflows/cycle-005-hosted-persistence-evidence.yml` with `preflight_only=true`

Non-goals (preflight-only explicitly does NOT do these):
- Apply Supabase SQL bundle (guardrail: `preflight_only=true` requires `skip_sql_apply=true`)
- Capture evidence / write evidence JSON
- Create a PR

## Definition: What "Green Preflight" Means

A preflight is "green" when ALL are true:

1. GitHub Actions run for `cycle-005-hosted-persistence-evidence` completes successfully (overall job status = success).
2. BASE_URL candidates exist and a deployed workflow runtime is selected:
   - Candidate probe ran and at least one candidate looks like a Next.js runtime serving `/api/workflow/*` (not a marketing/static site).
   - The workflow selected a concrete `BASE_URL` and printed it in the Step Summary.
3. Hosted runtime health gates pass for the selected `BASE_URL`:
   - `GET <BASE_URL>/api/workflow/env-health` returns HTTP 200 JSON with `.ok == true`.
   - The env-health JSON shows BOTH:
     - `.env.NEXT_PUBLIC_SUPABASE_URL == true`
     - `.env.SUPABASE_SERVICE_ROLE_KEY == true`
4. Supabase is healthy for the hosted runtime (preflight-only always runs this because it requires `skip_sql_apply=true`):
   - `GET <BASE_URL>/api/workflow/supabase-health?requireSeed=1&requirePilotDeals=1` returns HTTP 200 JSON with `.ok == true`.
   - Acceptance requires schema/seed to match expectations:
     - `.schema.actual_schema_bundle_id == .schema.expected_schema_bundle_id`
     - `.seed.present == true`
     - `.tables.workflow_runs == true`
     - `.tables.workflow_events == true`
     - `.tables.pilot_deals == true`
5. Preflight artifacts are uploaded and contain the expected evidence of checks (see below).

If `enable_autorun_after_preflight=true` was used, green preflight also requires:
- Repo variable `CYCLE_005_AUTORUN_ENABLED=true` was successfully upserted by the workflow (step "Enable scheduled autorun gate after green preflight").

## Where To Look In GitHub Actions (Logs + Artifacts)

In the GHA run UI, inspect these steps (names are exact from the workflow):

1. `Assemble + probe deployed BASE_URL candidates (always)`
   - Pass signal:
     - Step completes without exiting 2.
     - `preflight/base-url-candidates.txt` is non-empty.
     - `preflight/base-url-source.txt` indicates where candidates came from (input or repo var is preferred).
   - Fail signal:
     - Log includes "Missing BASE_URL candidates; failing run."
     - Step Summary includes `status: no BASE_URL candidates`.

2. `Select + validate deployed BASE_URL (fail-fast)`
   - Pass signal:
     - Log includes `Selected BASE_URL: https://...`
     - Step Summary includes `Selected BASE_URL: ...`
   - Fail signal:
     - "Failed to select a valid hosted BASE_URL from candidates."
     - Review `preflight/base-url-probe.txt` and `preflight/select-base-url.err`.

3. `Preflight: env-health (capture)`
   - Pass signal:
     - HTTP 200, JSON parses, `.ok == true`
     - Step Summary shows `has_supabase_env: true`
   - Key artifacts:
     - `preflight/env-health.json`

4. Optional auto-fix steps (only run when env is missing and toggles are enabled):
   - `Auto-fix (Vercel): upsert Supabase env vars + redeploy (best-effort)`
   - `Auto-fix (Cloudflare Pages): upsert Supabase env vars (+ optional deploy hook) (best-effort)`
   - Pass signal (if these ran):
     - A follow-up `preflight/env-health.after-redeploy.json` exists and shows env booleans true.
   - Risk note:
     - Auto-fix can be skipped due to missing provider tokens/project IDs or missing GitHub secrets for the env values.

5. `Preflight: env-health (enforce)`
   - Pass signal:
     - Step does not exit 2.
   - Fail signal:
     - "Hosted runtime is missing required Supabase env vars."

6. `Preflight: supabase-health (env + schema + seed) (only when skip_sql_apply=true)`
   - Pass signal:
     - HTTP 200, JSON parses, `.ok == true`
     - Step Summary prints `schema_expected` and `schema_actual`
   - Key artifact:
     - `preflight/supabase-health.json`

7. `Upload preflight artifacts (always)`
   - Expect artifact: `cycle-005-hosted-preflight`
   - Must contain (minimum):
     - `preflight/base-url-candidates.txt`
     - `preflight/base-url-source.txt`
     - `preflight/base-url-probe.txt`
     - `preflight/env-health.json` (and `preflight/env-health.after-redeploy.json` when applicable)
     - `preflight/supabase-health.json`

8. Optional: `Enable scheduled autorun gate after green preflight (optional; workflow_dispatch only)`
   - Only relevant when using the safe path (enable autorun only after green preflight).
   - Pass signal:
     - Step completes and Step Summary includes `schedule_gate_enabled: CYCLE_005_AUTORUN_ENABLED=true`
     - Artifact includes `preflight/github-api.actions-variables.autorun.patch.json` or `.post.json` with a successful upsert (HTTP 204 or 201).

9. `Stop after preflight (preflight_only=true)`
   - Pass signal:
     - Log includes "Preflight-only run requested; stopping before evidence execution."
     - Step Summary includes `preflight_only: true (skipping intake + evidence + PR)`

CLI helpers (optional) to inspect runs/artifacts:

```bash
REPO="junhengz/auto-company"
RUN_DBID="$(gh run list -R "$REPO" --workflow cycle-005-hosted-persistence-evidence.yml -L 1 --json databaseId -q '.[0].databaseId')"
gh run view -R "$REPO" "$RUN_DBID"
gh run download -R "$REPO" "$RUN_DBID" -n cycle-005-hosted-preflight
```

## Pre-Autorun Checklist (Before Setting `CYCLE_005_AUTORUN_ENABLED=true`)

Configuration readiness (must be true before enabling schedule):
- `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` repo variable is set (2-4 origins) and includes the real deployed Next.js workflow runtime.
- The selected runtime returns JSON for:
  - `GET <BASE_URL>/api/workflow/env-health`
  - `GET <BASE_URL>/api/workflow/supabase-health?requireSeed=1&requirePilotDeals=1`
- Hosted runtime provider env vars are configured (provider-side, not GitHub-side):
  - `NEXT_PUBLIC_SUPABASE_URL`
  - `SUPABASE_SERVICE_ROLE_KEY`
- Supabase schema + seed were already applied to the correct project (preflight-only cannot apply SQL by design).

Operational safety (decide explicitly):
- You accept the schedule cadence: the workflow is configured to run every 6 hours.
- You accept the PR behavior: evidence runs use a stable PR branch `cycle-005-hosted-persistence-evidence` and will update it on scheduled runs.
- If relying on auto-fix:
  - Vercel: `VERCEL_TOKEN` secret and `VERCEL_PROJECT_ID` or `VERCEL_PROJECT` vars are set.
  - Cloudflare Pages: `CLOUDFLARE_API_TOKEN` secret and `CLOUDFLARE_ACCOUNT_ID` + `CF_PAGES_PROJECT` vars are set.
  - GitHub secrets `NEXT_PUBLIC_SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` exist (required for provider env sync).

Proof (what you should have in hand):
- At least one successful preflight run artifact set (`cycle-005-hosted-preflight`) whose `preflight/env-health*.json` indicates env booleans true and whose `preflight/supabase-health.json` indicates `.ok == true` and matching schema bundle IDs.

## Known Blocker Observed In This Workspace (2026-02-14)

Attempted local preflight dispatch:

```bash
scripts/devops/run-cycle-005-hosted-persistence-evidence.sh \
  --repo junhengz/auto-company \
  --autodiscover-github \
  --preflight-only \
  --skip-sql-apply true
```

Result: failed before dispatch with "Missing BASE_URL candidates." This means:
- `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` is not set (or not readable) AND
- GitHub Deployments metadata did not yield any environment/target URLs for discovery.

Fix: set `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` (preferred) or pass `--base-url` for a one-off run, then rerun preflight.

