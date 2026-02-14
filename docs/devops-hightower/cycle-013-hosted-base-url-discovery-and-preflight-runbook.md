# Cycle 013: Hosted BASE_URL Discovery + Preflight Runbook

## Objective

Make hosted `BASE_URL` selection and Cycle 005 preflight/evidence runs deterministic for a maintainer.

Key constraint: **the canonical hosted `BASE_URL` cannot be derived from repo code**. It must be discovered from hosting provider domains/deployments and then validated by probing the workflow runtime endpoint:

- `GET <BASE_URL>/api/workflow/env-health` (must be `200` JSON with `.ok == true`)

For Cycle 005 evidence runs, the runtime must also report:

- `.env.NEXT_PUBLIC_SUPABASE_URL == true`
- `.env.SUPABASE_SERVICE_ROLE_KEY == true`

Those env vars must be set on the hosting provider runtime and redeployed.

## Maintainer Quick Path (Recommended)

1. Get 2-4 candidate origins from the hosting provider UI for the deployed **Next.js workflow runtime** (not a marketing/static domain).

2. Probe candidates locally (no secrets required):

```bash
./projects/security-questionnaire-autopilot/scripts/probe-hosted-base-url-candidates.sh \
  "https://candidate-1 https://candidate-2"
```

3. Select the correct runtime (strict: requires Supabase env flags):

```bash
./projects/security-questionnaire-autopilot/scripts/discover-hosted-base-url.sh \
  https://candidate-1 \
  https://candidate-2
```

If you are still wiring hosted env vars and only want runtime identification:

```bash
ALLOW_MISSING_SUPABASE_ENV=1 \
./projects/security-questionnaire-autopilot/scripts/discover-hosted-base-url.sh \
  https://candidate-1 \
  https://candidate-2
```

4. Persist candidates once as a GitHub Actions repo variable (preferred):

```bash
gh variable set HOSTED_WORKFLOW_BASE_URL_CANDIDATES -R OWNER/REPO --body \
  "https://candidate-1 https://candidate-2"
```

5. Run a **preflight-only** workflow dispatch (safe, read-only):

- Workflow: `.github/workflows/cycle-005-hosted-persistence-evidence.yml`
- Inputs:
  - `preflight_only=true`
  - `skip_sql_apply=true`
  - leave `base_url` empty (uses `HOSTED_WORKFLOW_BASE_URL_CANDIDATES`)

CLI dispatch (optional operator path):

```bash
./scripts/devops/run-cycle-005-hosted-persistence-evidence.sh \
  --repo OWNER/REPO \
  --preflight-only
```

## Repo Config Contract (What Must Exist)

### Variables (GitHub Actions repo variables)

- `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` (required for deterministic preflight)
- `CYCLE_005_AUTORUN_ENABLED` (optional schedule gate; keep `false` until preflight is green)

Optional provider discovery identifiers:

- Vercel:
  - `VERCEL_PROJECT_ID` or `VERCEL_PROJECT`
  - optional: `VERCEL_TEAM_ID` / `VERCEL_TEAM_SLUG`
- Cloudflare Pages:
  - `CF_PAGES_PROJECT`
  - `CLOUDFLARE_ACCOUNT_ID` (or allow auto-resolution if token sees only one account)

### Secrets (GitHub Actions secrets)

- Optional auto-fix (Vercel):
  - `VERCEL_TOKEN`
  - `VERCEL_DEPLOY_HOOK_URL` (optional)
- Optional auto-fix (Cloudflare Pages):
  - `CLOUDFLARE_API_TOKEN`
  - `CF_PAGES_DEPLOY_HOOK_URL` (optional)

Hosted runtime env values (used for auto-fix and for fallback mode; do not print):

- `NEXT_PUBLIC_SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

Only needed if `skip_sql_apply=false` (SQL apply inside CI):

- `SUPABASE_DB_URL`

## Evidence Run (After Green Preflight)

After preflight passes (valid `BASE_URL` + Supabase env vars + `supabase-health ok=true`), re-run:

- `preflight_only=false`

This runs `projects/security-questionnaire-autopilot/scripts/cycle-005-hosted-supabase-apply-and-run.sh`,
uploads evidence artifacts, and opens/updates a PR on branch `cycle-005-hosted-persistence-evidence`.

## Rollback / Safety

- Keep scheduled runs gated until proven:
  - `CYCLE_005_AUTORUN_ENABLED=false` (default)
- If a scheduled run creates noise, disable it immediately:

```bash
gh variable set CYCLE_005_AUTORUN_ENABLED -R OWNER/REPO --body false
```

## If Dispatch Fails With 404/422

If the repo/ref you are targeting does not yet contain the workflow on its default branch, the operator wrapper may fail with `HTTP 404` or `HTTP 422`.

Fix:

1. Merge/push the workflow into the canonical repo default branch, then rerun.
2. If the workflow exists on a non-default branch you control, rerun with `--ref <branch>`.

