# Cycle 011: Hosted Runtime Discovery + Hosted Persistence Evidence (CTO Runbook)

Date: 2026-02-14

## What We Are Unblocking
- Identify the deployed Next.js *workflow runtime* origin that serves `GET /api/workflow/env-health`.
- Get `cycle-005-hosted-persistence-evidence` preflight (`preflight_only=true`) to go green, then run full evidence.

## Status: PR #3 Autodiscovery Improvements (Present vs Missing)
This workspace branch (`cycle-008-hosting-discovery-v2`, HEAD `953c2f8`) includes the requested autodiscovery improvements:
- Cloudflare Pages: recent deployments + aliases via `/deployments` (production+preview) in `projects/security-questionnaire-autopilot/scripts/collect-base-url-candidates-from-cloudflare-pages-api.sh`.
- Vercel: production+preview deployments + deployment-alias enrichment (`/v2/deployments/{id}/aliases`) in `projects/security-questionnaire-autopilot/scripts/collect-base-url-candidates-from-vercel-api.sh`.

They are **not** available on the upstream repo default branch currently used by `origin` (`nicepkg/auto-company`): that repo has **0 GitHub Actions workflows** (so the Cycle 005 evidence workflow cannot be dispatched there).

## Minimum Inputs For Auto-Discovery (Provider-First)
If you have provider creds, you can discover candidates without guessing domains.

Vercel (recommended if the runtime is on Vercel):
- Secret: `VERCEL_TOKEN`
- Variable: `VERCEL_PROJECT_ID` (preferred) or `VERCEL_PROJECT`
- Optional variables (team-scoped projects): `VERCEL_TEAM_ID` or `VERCEL_TEAM_SLUG`

Cloudflare Pages:
- Secret: `CLOUDFLARE_API_TOKEN`
- Variables: `CLOUDFLARE_ACCOUNT_ID`, `CF_PAGES_PROJECT`
- Optional: `CF_PAGES_BRANCH` (defaults from `GITHUB_REF_NAME`), `CF_PAGES_DEPLOYMENTS_LIMIT`, `CF_PAGES_DEPLOYMENTS_ENVS`

GitHub Deployments metadata (best-effort, often empty):
- Requires the repo actually publishing Deployments statuses with `environment_url`/`target_url`.

## What “Correct BASE_URL” Means (Contract)
The evidence runner selects a `BASE_URL` by probing:
- `GET <BASE_URL>/api/workflow/env-health`

For preflight to pass, that endpoint must return JSON with:
- `ok=true`
- `env.NEXT_PUBLIC_SUPABASE_URL=true`
- `env.SUPABASE_SERVICE_ROLE_KEY=true`

If `ok=true` but env flags are false, the runtime is reachable but misconfigured: fix env vars on the hosting provider and redeploy.

## Preflight: What Is Blocking Right Now
### Attempt A: run against `nicepkg/auto-company` (upstream)
Command:
- `scripts/devops/run-cycle-005-hosted-persistence-evidence.sh --repo nicepkg/auto-company --preflight-only`

Observed blockers:
- Cannot read repo variables/secrets (HTTP 403) in the wrapper’s local checks.
- No `HOSTED_WORKFLOW_BASE_URL_CANDIDATES`, and autodiscovery yields no candidates.
- Even if candidates are provided, dispatch fails because the workflow does not exist on that repo (HTTP 404 on `actions/workflows/cycle-005-hosted-persistence-evidence.yml`).

Conclusion: you cannot run Cycle 005 evidence automation on `nicepkg/auto-company` until the workflows (and supporting scripts) are merged/present on that repo’s default branch/ref.

### Attempt B: run against `junhengz/auto-company` (fork that contains the workflow)
Command:
- `scripts/devops/run-cycle-005-hosted-persistence-evidence.sh --repo junhengz/auto-company --preflight-only --autodiscover`

Observed blocker:
- Missing `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` and no provider tokens/ids configured, so discovery returns empty.

Conclusion: we need either (1) 2-4 real deployed origins, or (2) provider creds + ids to discover them.

## Operational Runbook (Fastest Path)
1. Get 2-4 candidate origins from the hosting provider UI (Vercel Domains / Cloudflare Pages Domains), for the *workflow API app*.
2. Validate candidates locally:
   - `./projects/security-questionnaire-autopilot/scripts/probe-hosted-base-url-candidates.sh "https://c1 https://c2"`
3. Persist candidates into repo variable (recommended):
   - `gh variable set HOSTED_WORKFLOW_BASE_URL_CANDIDATES -R junhengz/auto-company --body "https://c1 https://c2"`
4. Run preflight-only:
   - `./scripts/devops/run-cycle-005-hosted-persistence-evidence.sh --repo junhengz/auto-company --preflight-only`
5. If preflight fails due to missing hosted env vars, set on the hosting provider *for that deployed runtime*:
   - `NEXT_PUBLIC_SUPABASE_URL`
   - `SUPABASE_SERVICE_ROLE_KEY`
   Then redeploy and re-run step 4.
6. Once preflight is green, run full evidence:
   - `./scripts/devops/run-cycle-005-hosted-persistence-evidence.sh --repo junhengz/auto-company`

