# Cycle 029 (DevOps-Hightower): Unblock Hosted Runtime Origins For Cycle 005 Preflight

Date: 2026-02-14

Repo (workspace): `/home/zjohn/autocomp/auto-company`

## Current Infra Status (Observed 2026-02-14)

We do not currently have a publicly reachable **workflow API runtime** origin for this repo.

Evidence (curl probes):

- `https://auto-company.pages.dev/api/workflow/env-health` returns `200` **HTML** (marketing/static site catch-all), not JSON.
- `https://auto-company.vercel.app/api/workflow/env-health` returns `404 DEPLOYMENT_NOT_FOUND` (no active Vercel deployment).
- `https://security-questionnaire-autopilot.pages.dev/api/workflow/env-health` is `NXDOMAIN` (no Pages project).

Conclusion: `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` cannot be populated with real origins until we deploy the app under `projects/security-questionnaire-autopilot/` to a hosting provider and get one or more stable domains.

## What “Correct” Looks Like (Hard Contract)

Cycle 005 preflight requires a `BASE_URL` where this passes:

```bash
BASE_URL="https://<your-runtime-origin>"
curl -sS "$BASE_URL/api/workflow/env-health" | jq -e \
  '.ok==true and .env.NEXT_PUBLIC_SUPABASE_URL==true and .env.SUPABASE_SERVICE_ROLE_KEY==true'
```

Notes:

- `env-health` returns booleans only (no secret values).
- A “wrong” `BASE_URL` commonly returns HTML, `404`, or redirects.

## Fastest Path To A Real Hosted Origin (Recommended: Single-Instance Container)

This Next.js runtime executes a local Python CLI (`python3 -m sq_autopilot.cli`) and writes run artifacts under `projects/security-questionnaire-autopilot/runs/`.

That combination is fragile on serverless platforms that are:

- missing `python3`, and/or
- read-only at the project root, and/or
- not sticky across requests (subsequent calls may land on a different instance without the run files).

To get a stable public origin quickly, deploy it as a **single-instance container service** (Cloud Run / Fly.io / Render / Railway), then cap scaling so sequential workflow calls during evidence runs hit the same instance.

### Cloud Run Reference (One Good Default)

Target: container listens on `$PORT`, serves `GET /api/workflow/env-health` and all `/api/workflow/*` routes.

Concrete recipe (works on Cloud Run, Fly.io, Render, Railway, etc):

1. Use `projects/security-questionnaire-autopilot/Dockerfile` (added below).
2. Deploy with `max-instances=1` and `concurrency=1` to reduce cross-instance run state issues during evidence runs.
3. Set runtime env vars (next section).
4. Verify with curl.

Example Cloud Run commands (edit placeholders):

```bash
gcloud config set project "<gcp-project-id>"

IMAGE="gcr.io/<gcp-project-id>/sq-autopilot-hosted:$(date +%Y%m%d-%H%M%S)"
gcloud builds submit projects/security-questionnaire-autopilot --tag "$IMAGE"

gcloud run deploy "sq-autopilot-hosted" \
  --image "$IMAGE" \
  --region "us-central1" \
  --allow-unauthenticated \
  --max-instances=1 \
  --min-instances=1 \
  --concurrency=1 \
  --set-env-vars "NEXT_PUBLIC_SUPABASE_URL=<https://...>,SUPABASE_SERVICE_ROLE_KEY=<...>"
```

Verification:

```bash
BASE_URL="https://<cloud-run-service-url>"
curl -sS "$BASE_URL/api/workflow/env-health" | jq .
curl -sS "$BASE_URL/api/workflow/env-health" | jq -e '.ok==true'
curl -sS "$BASE_URL/api/workflow/env-health" | jq -e \
  '.env.NEXT_PUBLIC_SUPABASE_URL==true and .env.SUPABASE_SERVICE_ROLE_KEY==true'
```

Rollback plan:

- If deploy is broken, redeploy the last known-good image tag, or temporarily set `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` empty to stop scheduled runs from flapping.

### Dockerfile (Reference)

See: `projects/security-questionnaire-autopilot/Dockerfile`.

## Repo Variable + Secrets: What Must Be Set

### 1) GitHub Actions Variable (Required For Deterministic BASE_URL Selection)

Set this on the target repo you dispatch Cycle 005 from (typically `nicepkg/auto-company`):

- Variable: `HOSTED_WORKFLOW_BASE_URL_CANDIDATES`
- Value: `2-4` space/comma/newline separated origins, for example:
  - `https://sq-autopilot-prod-<hash>-uc.a.run.app`
  - `https://<custom-domain>`

CLI:

```bash
gh variable set HOSTED_WORKFLOW_BASE_URL_CANDIDATES -R nicepkg/auto-company \
  --body "https://<origin1> https://<origin2>"
```

### 2) Hosting Provider Env Vars (Authoritative For Runtime Behavior)

These must be set on the hosting provider for the deployed runtime (Production at minimum), then redeployed:

- `NEXT_PUBLIC_SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

### 3) GitHub Actions Secrets/Vars (Optional, For Automation)

Only needed if you want the workflows to auto-discover hosting candidates and/or auto-sync hosted env vars:

- Vercel autodiscovery/env-sync:
  - Secret: `VERCEL_TOKEN`
  - Variable: `VERCEL_PROJECT_ID` (preferred) or `VERCEL_PROJECT`
  - Optional variables: `VERCEL_TEAM_ID`, `VERCEL_TEAM_SLUG`
- Cloudflare Pages autodiscovery/env-sync:
  - Secret: `CLOUDFLARE_API_TOKEN`
  - Variables: `CLOUDFLARE_ACCOUNT_ID`, `CF_PAGES_PROJECT`
  - Optional: `CF_PAGES_DEPLOY_HOOK_URL` (to trigger redeploy)

## Quick Verification Checklist (Operator Copy/Paste)

```bash
BASE_URL="https://<your-runtime-origin>"

# Must be JSON + ok=true
curl -sS "$BASE_URL/api/workflow/env-health" | jq -e '.ok==true'

# Must show both env vars present (booleans only)
curl -sS "$BASE_URL/api/workflow/env-health" | jq -e \
  '.env.NEXT_PUBLIC_SUPABASE_URL==true and .env.SUPABASE_SERVICE_ROLE_KEY==true'
```

If those pass, Cycle 005 preflight can select the runtime deterministically once
`HOSTED_WORKFLOW_BASE_URL_CANDIDATES` is set.
