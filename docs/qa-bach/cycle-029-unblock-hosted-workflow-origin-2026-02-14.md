# Cycle 029 (qa-bach): Unblock Hosted Workflow Runtime Origin(s) for Cycle 005 Preflight

## Goal (what must exist)
A *real deployed* Next.js runtime serving the workflow API must be reachable at a stable origin such that:

- `GET <BASE_URL>/api/workflow/env-health` returns HTTP `200` and JSON
- JSON contains:
  - `.ok == true`
  - `.env.NEXT_PUBLIC_SUPABASE_URL == true`
  - `.env.SUPABASE_SERVICE_ROLE_KEY == true`

Source of truth for the probe implementation:
- `projects/security-questionnaire-autopilot/app/api/workflow/env-health/route.ts`

## Current State (2026-02-14)
Evidence captured under `docs/qa-bach/`:

- GitHub Deployments metadata is empty (no discoverable deployment URLs):
  - `docs/qa-bach/cycle-029-gh-deployments-junhengz-auto-company-2026-02-14.json`
  - `docs/qa-bach/cycle-029-gh-deployments-nicepkg-auto-company-2026-02-14.json`
- Repo variable `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` is missing in `junhengz/auto-company` (HTTP 404):
  - `docs/qa-bach/cycle-029-gh-var-hosted-workflow-base-url-candidates-junhengz-auto-company-2026-02-14.json`
- Repo variable read is forbidden for `nicepkg/auto-company` in current GH auth context (HTTP 403):
  - `docs/qa-bach/cycle-029-gh-var-hosted-workflow-base-url-candidates-nicepkg-auto-company-2026-02-14.json`

Operationally: current public `https://auto-company.pages.dev` is a marketing/static site (HTML at `/api/workflow/env-health`), not the workflow runtime.

## Fastest Path: Create a Vercel Production Deployment (recommended)
This is the shortest path to a stable origin that supports `/api/workflow/*`.

1. Create a new Vercel project
- Import: GitHub repo `junhengz/auto-company` (or the canonical repo that will host the runtime)
- Root Directory: `projects/security-questionnaire-autopilot`
- Framework: Next.js (package uses `next@14`)
- Build Command: `npm run build` (default)
- Output: Vercel will assign a stable production domain like `https://<project>.vercel.app`
  - If you name the Vercel project `security-questionnaire-autopilot-hosted`, you will typically get `https://security-questionnaire-autopilot-hosted.vercel.app`

2. Configure hosted runtime env vars in Vercel (source of truth for env-health)
Set in Vercel Project -> Settings -> Environment Variables (Production at minimum), then redeploy:
- `NEXT_PUBLIC_SUPABASE_URL` (non-secret)
- `SUPABASE_SERVICE_ROLE_KEY` (secret)

3. Verify the deployed runtime with curl
Replace `BASE_URL` with the Vercel production origin.

- Quick check (must be JSON, not HTML):
  - `curl -sS "$BASE_URL/api/workflow/env-health" | jq .`

- Hard gate (must exit 0):
  - `curl -sS "$BASE_URL/api/workflow/env-health" | jq -e '.ok==true and .env.NEXT_PUBLIC_SUPABASE_URL==true and .env.SUPABASE_SERVICE_ROLE_KEY==true'`

- Save evidence (headers + body):
  - `curl -sS -D env-health.headers.txt -o env-health.json -w "%{http_code}\n" "$BASE_URL/api/workflow/env-health"`

4. Persist the origin(s) for Cycle 005
Set 2-4 origins (custom domain + `*.vercel.app` + 1 backup if you have it). Origins only (no paths).

- For `junhengz/auto-company`:
  - `gh variable set HOSTED_WORKFLOW_BASE_URL_CANDIDATES -R junhengz/auto-company --body "https://<prod-origin> https://<backup-origin>"`

## Alternative: Cloudflare Pages (only if you already have it configured)
Cloudflare Pages can be used *if* the deployed app actually serves the Next.js route handler for `/api/workflow/env-health`.

Required Cloudflare Pages hosted env vars (Production), then trigger a new deployment:
- `NEXT_PUBLIC_SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

Verification is identical via curl.

## Repo Vars/Secrets Checklist (what to set where)
### Minimum for Cycle 005 preflight to select a real runtime
GitHub Actions repo variable (in the repo that runs `cycle-005-hosted-persistence-evidence`):
- `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` (value: `https://origin1 https://origin2`)

Optional but recommended:
- `CYCLE_005_AUTORUN_ENABLED=true` (repo variable) to allow scheduled runs to proceed

### Optional: allow the workflow to auto-fix hosted env via provider APIs
If you want `attempt_vercel_env_sync=true` to work (or want to run `.github/workflows/cycle-005-hosted-runtime-env-sync.yml`):

GitHub Secrets:
- `NEXT_PUBLIC_SUPABASE_URL` (used as source-of-truth to sync into hosting)
- `SUPABASE_SERVICE_ROLE_KEY` (used as source-of-truth to sync into hosting)
- `VERCEL_TOKEN` (Vercel REST API)
- `VERCEL_DEPLOY_HOOK_URL` (optional; if set, can trigger deploy without guessing)

GitHub Vars:
- `VERCEL_PROJECT_ID` (preferred) or `VERCEL_PROJECT` (project name)
- `VERCEL_TEAM_ID` or `VERCEL_TEAM_SLUG` (only if the Vercel project is team-scoped)

Cloudflare Pages (if using Cloudflare automation):

GitHub Secrets:
- `CLOUDFLARE_API_TOKEN`
- `CF_PAGES_BUILD_HOOK_URL` (optional; redeploy automation)

GitHub Vars:
- `CLOUDFLARE_ACCOUNT_ID` (or rely on account auto-resolution if token sees one account)
- `CF_PAGES_PROJECT`

## Quick Local Probe Table (when you have candidate origins)
Use this before persisting candidates:

- `./projects/security-questionnaire-autopilot/scripts/probe-hosted-base-url-candidates.sh "https://c1 https://c2"`

It prints:
- HTTP code
- `.ok`
- the two required env booleans
- a body sniff for HTML/404 cases
