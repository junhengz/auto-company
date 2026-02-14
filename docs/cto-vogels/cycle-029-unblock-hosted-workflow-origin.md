# Cycle 029: Unblock Hosted Workflow Origin(s) For Cycle 005 Preflight (2026-02-14)

Goal: make at least one **public** `BASE_URL` exist that serves the Next.js workflow API routes under `projects/security-questionnaire-autopilot/app/api/workflow/*`, specifically:

```bash
curl -fsSL "<BASE_URL>/api/workflow/env-health" | jq -e \
  '.ok==true and .env.NEXT_PUBLIC_SUPABASE_URL==true and .env.SUPABASE_SERVICE_ROLE_KEY==true'
```

## Current State (2026-02-14)

There is no confirmed, publicly reachable hosted origin for this repo that returns JSON from `GET /api/workflow/env-health`. Previous probes hit:

- HTML (static/marketing) at `auto-company.pages.dev`
- `DEPLOYMENT_NOT_FOUND` on common `*.vercel.app` guesses

So the only “green preflight” path so far has been the credential-free `local_runtime=true` fallback. This document is the fastest path to replacing that with a real hosted origin.

## What Is “The Workflow Runtime” (And What It Is Not)

The workflow runtime is the Next.js app in this repo rooted at:

- `projects/security-questionnaire-autopilot/`

The health endpoint is implemented in:

- `projects/security-questionnaire-autopilot/app/api/workflow/env-health/route.ts`

Marketing/static sites (including `auto-company.pages.dev`) are **not** valid origins; they return HTML or 404 for `/api/workflow/*`.

## Fastest Path: Deploy The Runtime To Vercel (Recommended)

Vercel is the shortest path because it natively supports Next.js `app/` API routes with minimal glue.

### Steps (Vercel UI)

1. Create a new Vercel Project from the GitHub repo.
2. Set **Root Directory** to `projects/security-questionnaire-autopilot`.
3. Ensure Node is `>= 20` (see `projects/security-questionnaire-autopilot/.nvmrc`).
4. Deploy.

Naming: if you name the Vercel project `security-questionnaire-autopilot-hosted`, the default production domain is typically:

- `https://security-questionnaire-autopilot-hosted.vercel.app`

(Use the actual production domain shown in Vercel; do not rely on guesses.)

### Set Required Hosted Runtime Env Vars (On Vercel)

Set these env vars on the Vercel Project (Production at minimum; Preview optional):

- `NEXT_PUBLIC_SUPABASE_URL` (plain)
- `SUPABASE_SERVICE_ROLE_KEY` (secret)

Then redeploy (or “Redeploy” the latest Production deployment).

### Verify The Origin With curl

```bash
BASE_URL="https://<your-vercel-production-domain>"

curl -fsSL "$BASE_URL/api/workflow/env-health" | jq .
curl -fsSL "$BASE_URL/api/workflow/env-health" | jq -e \
  '.deploy.provider=="vercel" and .ok==true'
curl -fsSL "$BASE_URL/api/workflow/env-health" | jq -e \
  '.env.NEXT_PUBLIC_SUPABASE_URL==true and .env.SUPABASE_SERVICE_ROLE_KEY==true'
```

If you see `"deploy": { "provider": "unknown" }`, you are likely not hitting Vercel/Pages or the platform env vars are not present.

## Alternative: Cloudflare Pages (Only If You Already Use Pages For This Runtime)

This repo contains automation for **syncing env vars** into an existing Cloudflare Pages project, but it does not guarantee the Next.js runtime is already correctly deployed on Pages.

If (and only if) you already have a Pages project that serves `/api/workflow/env-health` as JSON:

```bash
BASE_URL="https://<your-pages-domain>"
curl -fsSL "$BASE_URL/api/workflow/env-health" | jq -e '.deploy.provider=="cloudflare_pages"'
```

Then ensure Pages has the required env vars and trigger a redeploy.

## Repo Variable: The Source Of Truth For Origin Selection

Cycle 005 selects a `BASE_URL` by probing candidates and requiring `/api/workflow/env-health` JSON.

Set the variable on the repo where you run the workflow (e.g. `nicepkg/auto-company` if that is the canonical `origin`, not just your fork).

Set this repo variable (space/comma/newline separated; no paths):

- `HOSTED_WORKFLOW_BASE_URL_CANDIDATES`

Example:

```bash
gh variable set HOSTED_WORKFLOW_BASE_URL_CANDIDATES -R <OWNER>/<REPO> --body \
"https://<prod-domain> https://<secondary-domain>"
```

Then verify the workflow can select it:

```bash
curl -fsSL "https://<prod-domain>/api/workflow/env-health" | jq -e '.ok==true'
```

## Exactly What Vars/Secrets Must Be Set (For Hosted Preflight)

Two different “env surfaces” exist:

1. Hosting provider env vars (Vercel/Pages): required for the runtime itself.
2. GitHub Actions vars/secrets: required only for discovery/auto-fix and for non-preflight modes.

### Hosting Provider (Required)

Set on the deployed Next.js runtime (the thing serving `/api/workflow/*`):

- `NEXT_PUBLIC_SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

### GitHub Repo Variables (Required)

Required to unblock deterministic BASE_URL selection:

- `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` (2-4 origins recommended)

Optional:

- `CYCLE_005_AUTORUN_ENABLED=true` (only if you want scheduled runs enabled)

### GitHub Secrets/Vars (Optional, Enables Auto-Fix + Discovery)

These are used by:

- `.github/workflows/cycle-005-hosted-persistence-evidence.yml` (auto-fix if env-health booleans are false)
- `.github/workflows/cycle-005-hosted-runtime-env-sync.yml` (manual env sync workflow)

Vercel (optional automation):

- Secret: `VERCEL_TOKEN`
- Var: `VERCEL_PROJECT_ID` (or `VERCEL_PROJECT`)
- Var: `VERCEL_TEAM_ID` (optional)
- Var: `VERCEL_TEAM_SLUG` (optional)
- Secret: `VERCEL_DEPLOY_HOOK_URL` (optional fallback redeploy path)
- Secret: `NEXT_PUBLIC_SUPABASE_URL` (source-of-truth value for sync)
- Secret: `SUPABASE_SERVICE_ROLE_KEY` (source-of-truth value for sync)

Cloudflare Pages (optional automation):

- Secret: `CLOUDFLARE_API_TOKEN`
- Var: `CLOUDFLARE_ACCOUNT_ID`
- Var: `CF_PAGES_PROJECT`
- Secret: `CF_PAGES_BUILD_HOOK_URL` (optional; triggers redeploy/build)
- Secret: `CF_PAGES_DEPLOY_HOOK_URL` (optional; used by some helper scripts)
- Secret: `NEXT_PUBLIC_SUPABASE_URL` (source-of-truth value for sync)
- Secret: `SUPABASE_SERVICE_ROLE_KEY` (source-of-truth value for sync)

## Failure Modes To Expect (And What They Mean)

- `/api/workflow/env-health` returns HTML:
  - Wrong `BASE_URL` (marketing/static domain, CDN rewrite, or wrong app).
- `/api/workflow/env-health` returns JSON but env booleans are `false`:
  - Correct runtime, missing hosted env vars, or redeploy not applied yet.
- `/api/workflow/env-health` is OK but Cycle 005 still fails later at `supabase-health`:
  - Supabase schema/seed not applied, or applied to the wrong Supabase project.

## Next Action

Create a Vercel Project with Root Directory `projects/security-questionnaire-autopilot`, set `NEXT_PUBLIC_SUPABASE_URL` + `SUPABASE_SERVICE_ROLE_KEY` on Vercel, then set repo variable `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` to that Vercel production domain and re-run Cycle 005 with `preflight_only=true`.
