# Cycle 029 (Operations/PG): Unblock Hosted Persistence Preflight by Creating a Real Workflow Runtime Origin (2026-02-14)

## Goal
Produce at least one publicly reachable **hosted** `BASE_URL` for the Next.js workflow runtime (not the marketing site) so Cycle 005 preflight can deterministically pass:

- `GET <BASE_URL>/api/workflow/env-health` returns HTTP `200` JSON
- JSON has `.ok == true`
- JSON has `.env.NEXT_PUBLIC_SUPABASE_URL == true`
- JSON has `.env.SUPABASE_SERVICE_ROLE_KEY == true`

## Current State (Why Discovery Is Blocked)
- GitHub Deployments metadata is empty for `junhengz/auto-company` (no `environment_url` / `target_url` to scrape), so BASE_URL cannot be inferred automatically.
- `https://auto-company.pages.dev/api/workflow/env-health` returns HTML, which indicates it is a static/marketing deployment, not the workflow runtime.

The fix is to create a real hosted origin for `projects/security-questionnaire-autopilot` and then set `HOSTED_WORKFLOW_BASE_URL_CANDIDATES`.

## The Fastest Path: Deploy the Workflow Runtime to Vercel

### 1) Create the Vercel Project (UI)
In Vercel, import `junhengz/auto-company` and configure:

- Framework: Next.js (auto-detected)
- Root Directory: `projects/security-questionnaire-autopilot`
- Production branch: `main`

Deploy once (even if Supabase is not ready yet). This gives you a stable `*.vercel.app` origin.

### 2) Set Hosted Runtime Env Vars (Vercel)
In Vercel Project Settings -> Environment Variables, set at minimum for `Production`:

- `NEXT_PUBLIC_SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

Recommended: also set for `Preview` so preview URLs pass `env-health` too.

Trigger a new deployment (redeploy) so the runtime picks up env vars.

### 3) Verify the Origin with curl (Must Be JSON)
Run this locally:

```bash
BASE_URL="https://<your-vercel-production-domain>"
curl -sS "$BASE_URL/api/workflow/env-health" | jq -e '
  .ok==true and
  .env.NEXT_PUBLIC_SUPABASE_URL==true and
  .env.SUPABASE_SERVICE_ROLE_KEY==true
'
```

If you want a friendlier check, run:

```bash
./docs/operations/cycle-029-verify-hosted-origin.sh "$BASE_URL"
```

Expected: it prints provider metadata and exits `0`.

### 4) Persist the Real Origin(s) for Cycle 005
Set `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` on the repo that runs Cycle 005 (the repo that contains `.github/workflows/cycle-005-hosted-persistence-evidence.yml`, recommended: `junhengz/auto-company`):

```bash
REPO="junhengz/auto-company"
gh variable set HOSTED_WORKFLOW_BASE_URL_CANDIDATES -R "$REPO" --body \
  "https://<vercel-production-domain> https://<optional-second-origin>"
```

Notes:
- Provide 2-4 origins if you have them (production domain, custom domain, etc).
- Do not include paths or trailing slashes.

### 5) Re-run Cycle 005 Preflight
```bash
./scripts/devops/run-cycle-005-hosted-persistence-evidence.sh \
  --repo "junhengz/auto-company" \
  --preflight-only
```

If Supabase is not provisioned yet, temporarily validate only BASE_URL + env-health:

```bash
./scripts/devops/run-cycle-005-hosted-persistence-evidence.sh \
  --repo "junhengz/auto-company" \
  --preflight-only \
  --preflight-require-supabase-health false
```

## Alternative: Cloudflare Pages (Only If You Already Use It for Full-Stack)
Cloudflare Pages can work, but Vercel is lower-friction for Next.js.

If using Pages, you must deploy the Next.js runtime (not static export) from:

- Root Directory: `projects/security-questionnaire-autopilot`

Then set on the Pages Project (Production + Preview):

- `NEXT_PUBLIC_SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

Verify via:

```bash
BASE_URL="https://<your-pages-domain>"
curl -sS "$BASE_URL/api/workflow/env-health" | jq .
```

## Exact Repo Vars and Secrets (Cycle 005 / Hosted Runtime)

### Required To Make Preflight Deterministic
- Repo variable: `HOSTED_WORKFLOW_BASE_URL_CANDIDATES`
- Variable value: 2-4 origins for the deployed workflow runtime serving `/api/workflow/env-health`

### Required On the Hosting Provider (Vercel/Pages/etc)
- Hosted env var: `NEXT_PUBLIC_SUPABASE_URL`
- Hosted env var: `SUPABASE_SERVICE_ROLE_KEY`

### Recommended (Enables “Auto-fix env vars + redeploy” in GitHub Actions)
These are only required if you want `.github/workflows/cycle-005-hosted-runtime-env-sync.yml` and Cycle 005 auto-fix to work.

- Repo secret: `NEXT_PUBLIC_SUPABASE_URL`
- Repo secret: `SUPABASE_SERVICE_ROLE_KEY`

Vercel automation:
- Repo secret: `VERCEL_TOKEN`
- Repo variable: `VERCEL_PROJECT_ID` (preferred) or `VERCEL_PROJECT`
- Repo variable: `VERCEL_TEAM_ID` or `VERCEL_TEAM_SLUG` (only for team-scoped projects)
- Optional repo secret: `VERCEL_DEPLOY_HOOK_URL` (if you prefer deploy-hook redeploy)

Cloudflare Pages automation:
- Repo secret: `CLOUDFLARE_API_TOKEN`
- Repo variable: `CLOUDFLARE_ACCOUNT_ID`
- Repo variable: `CF_PAGES_PROJECT`
- Optional repo secret: `CF_PAGES_DEPLOY_HOOK_URL` (to trigger redeploy after env update; used by Cycle 005 auto-fix scripts)
- Optional repo secret: `CF_PAGES_BUILD_HOOK_URL` (alternate hook name used by `.github/workflows/cycle-005-hosted-runtime-env-sync.yml`)

## How To Get Provider IDs (If Enabling Automation)

Vercel:

```bash
export VERCEL_TOKEN="..."
./projects/security-questionnaire-autopilot/scripts/vercel-list-projects.sh | head
```

Cloudflare:

```bash
export CLOUDFLARE_API_TOKEN="..."
./projects/security-questionnaire-autopilot/scripts/cloudflare-list-accounts.sh
./projects/security-questionnaire-autopilot/scripts/cloudflare-pages-list-projects.sh "<account_id>" | head
```

## Common Failure Modes (Fast Diagnosis)
- `env-health` returns HTML: wrong `BASE_URL` (marketing/static site or catch-all rewrite).
- `env-health` is JSON but env booleans are false: hosted env vars not set, or you set them but did not redeploy.
- `env-health` is 404: wrong project root deployed or not the workflow runtime.

## Next Action
Deploy `projects/security-questionnaire-autopilot` to Vercel as a real hosted runtime, verify `/api/workflow/env-health` returns `ok=true` with both env booleans true, then set `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` on `junhengz/auto-company` and rerun Cycle 005 preflight.
