# Cycle 011 (Operations/PG): Hosted Runtime Discovery Runbook (2026-02-14)

## Goal
Get a **green preflight** for `cycle-005-hosted-persistence-evidence` by making BASE_URL discovery deterministic (or provider-backed), then persist the correct origins for repeatable evidence runs.

## What “Correct BASE_URL” Means
BASE_URL must be the deployed Next.js app that serves the workflow API:

- `GET <BASE_URL>/api/workflow/env-health` returns JSON with `ok=true`

If you paste a marketing/static domain or a stale Vercel preview URL, the probe will return HTML/404/`DEPLOYMENT_NOT_FOUND` and preflight will fail.

## Fastest Path (Manual Copy/Paste, 5 min)
1. Collect 2-4 **production** origins from your host UI:
- Vercel: Production deployment domain(s) and any custom domains
- Cloudflare Pages: `*.pages.dev` production + any custom domains

2. Persist them to the repo variable:
```bash
REPO="OWNER/REPO"
gh variable set HOSTED_WORKFLOW_BASE_URL_CANDIDATES -R "$REPO" --body "https://app.example.com https://app2.example.com"
```

3. Run preflight-only:
```bash
./scripts/devops/run-cycle-005-hosted-persistence-evidence.sh --repo "$REPO" --preflight-only
```

## Zero-Dashboard Path (Provider API Discovery, 10-15 min one-time setup)
If you can set **provider tokens + ids** as repo secrets/variables, the workflow can discover fresh deployments without humans copying URLs.

### Vercel (Discovery)
- Secret: `VERCEL_TOKEN`
- Variable: `VERCEL_PROJECT_ID` (preferred) or `VERCEL_PROJECT`
- Optional variables (team-scoped projects): `VERCEL_TEAM_ID`, `VERCEL_TEAM_SLUG`

Local test (prints candidates):
```bash
export VERCEL_TOKEN="..."
export VERCEL_PROJECT_ID="..."
./projects/security-questionnaire-autopilot/scripts/collect-base-url-candidates-from-vercel-api.sh | head
```

### Cloudflare Pages (Discovery)
- Secret: `CLOUDFLARE_API_TOKEN`
- Variable: `CLOUDFLARE_ACCOUNT_ID`
- Variable: `CF_PAGES_PROJECT`

Local test (prints candidates):
```bash
export CLOUDFLARE_API_TOKEN="..."
export CLOUDFLARE_ACCOUNT_ID="..."
export CF_PAGES_PROJECT="..."
./projects/security-questionnaire-autopilot/scripts/collect-base-url-candidates-from-cloudflare-pages-api.sh | head
```

### Preflight Run (Discovery Enabled)
```bash
REPO="OWNER/REPO"
./scripts/devops/run-cycle-005-hosted-persistence-evidence.sh --repo "$REPO" --preflight-only --autodiscover
```

If it finds good candidates, persist them (recommended) by setting `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` (manual) or re-running with explicit `--base-url ...` and `--persist-candidates`.

## If Preflight Fails
- Failure: `Missing BASE_URL candidates`
  - Fix: set `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` or provide `--base-url ...`
- Failure: `env-health ok but missing NEXT_PUBLIC_SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY`
  - Fix: set hosted runtime env vars in the provider and redeploy, then rerun preflight
- Failure: everything 404 / `DEPLOYMENT_NOT_FOUND`
  - Fix: your candidates are stale or the wrong service; re-collect production origins from the host UI

