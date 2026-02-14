# Cycle 021: Hosted Workflow Runtime Origins Status (2026-02-14)

Repo: `junhengz/auto-company`

## Current State (Observed)

- `https://auto-company.pages.dev` is reachable but is a marketing/static site (Astro) with a catch-all fallback.
  - `GET /api/workflow/env-health` returns HTML (not JSON), so it is not the workflow API runtime.
- No GitHub Deployments metadata is available (`/repos/:owner/:repo/deployments` returns `[]`), so the repository cannot self-discover a runtime origin via Deployments.
- Common Vercel default domains like `https://auto-company.vercel.app` return `404 DEPLOYMENT_NOT_FOUND`.

Conclusion: there is currently **no publicly reachable production workflow runtime** origin for this repo that serves `GET /api/workflow/env-health` as JSON.

## What “Correct” Looks Like (Hard Gate)

A valid workflow runtime origin must satisfy:

```bash
curl -sS "<BASE_URL>/api/workflow/env-health" | jq -e \
  '.ok==true and .env.NEXT_PUBLIC_SUPABASE_URL==true and .env.SUPABASE_SERVICE_ROLE_KEY==true'
```

## Durable Fix (Production)

1. Deploy the Next.js workflow runtime (the app under `projects/security-questionnaire-autopilot/`) to a real hosting provider (Vercel or Cloudflare Pages Functions/Next-on-Pages).
2. Set the hosted runtime env vars on that provider:
   - `NEXT_PUBLIC_SUPABASE_URL`
   - `SUPABASE_SERVICE_ROLE_KEY`
3. Set repo variable `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` to 2-4 production origins.
4. Run Cycle 005 hosted preflight until green (then run evidence).

## Credential-Free Fallback (1 Cycle): Env-Only Preflight

If you do not yet have hosting + Supabase provisioned, you can still validate that the workflow runner can:

- reach a hosted runtime origin
- confirm `/api/workflow/env-health` is JSON and shows both env booleans `true`

This repo now supports skipping `supabase-health` during preflight by setting:

- `preflight_require_supabase_health=false`

Operator helper:

```bash
scripts/devops/run-cycle-005-hosted-preflight-quick-tunnel.sh --repo junhengz/auto-company --install-deps
```

Important: the Quick Tunnel URL is ephemeral and must not be persisted into `HOSTED_WORKFLOW_BASE_URL_CANDIDATES`.

