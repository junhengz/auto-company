# Cycle 011: Hosted Runtime Discovery Audit (QA-Bach)

Date (UTC): 2026-02-14  
Repo (upstream): `nicepkg/auto-company`  
Local branch inspected: `cycle-008-hosting-discovery-v2` (PR #3)

## Goal
Confirm whether PR #3 autodiscovery improvements exist, and what minimum inputs are needed to auto-discover the deployed workflow runtime origin(s) (Vercel or Cloudflare Pages).

## 1) PR #3 Autodiscovery Improvements: Present in Branch, Not in `main`

Upstream status:
- PR #3 is **OPEN**: "Cycle 008: expand hosted BASE_URL autodiscovery"
- Upstream `main` currently has **zero** GitHub Actions workflows (cannot run discovery/preflight there yet).

Evidence:
- `gh pr view 3 -R nicepkg/auto-company` -> OPEN (head: `cycle-008-hosting-discovery-v2`, base: `main`)
- `gh api repos/nicepkg/auto-company/actions/workflows` -> `{ total_count: 0, workflows: [] }`

Autodiscovery implementation in this branch:
- Cloudflare Pages: recent deployments + aliases
  - `projects/security-questionnaire-autopilot/scripts/collect-base-url-candidates-from-cloudflare-pages-api.sh`
  - Uses `/pages/projects/{project}/deployments` and collects `.aliases[]` plus URL fields, iterating `env=production,preview`.
- Vercel: production + preview deployments + deployment aliases
  - `projects/security-questionnaire-autopilot/scripts/collect-base-url-candidates-from-vercel-api.sh`
  - Defaults `targets="production,preview"`, collects `.url` + inline `.aliases[]`, and additionally fetches `/v2/deployments/{id}/aliases` for branch/preview alias coverage.
- Provider aggregator:
  - `projects/security-questionnaire-autopilot/scripts/collect-base-url-candidates-from-hosting.sh`
- Deterministic selection:
  - `projects/security-questionnaire-autopilot/scripts/select-hosted-base-url.sh`
  - Final check is `GET <BASE_URL>/api/workflow/env-health`.

## 2) Minimum Inputs For Autodiscovery (Provider-First)

### Vercel (preferred when Vercel creds exist)
Required:
- `VERCEL_TOKEN` (GitHub secret in GHA; env var locally)
- `VERCEL_PROJECT_ID` or `VERCEL_PROJECT` (GitHub variable in GHA; env var locally)

Optional (team-scoped projects / better coverage):
- `VERCEL_TEAM_ID` and/or `VERCEL_TEAM_SLUG`

Notes:
- Deployments scan defaults to `production,preview` and will attempt limited alias fetches per deployment (tunable via `VERCEL_DEPLOYMENTS_ALIAS_SCAN_LIMIT`).

### Cloudflare Pages (preferred when Pages creds exist)
Required:
- `CLOUDFLARE_API_TOKEN` (GitHub secret in GHA; env var locally)
- `CLOUDFLARE_ACCOUNT_ID` (GitHub variable in GHA; env var locally)
- `CF_PAGES_PROJECT` (GitHub variable in GHA; env var locally)

Optional:
- `CF_PAGES_BRANCH` (improves branch alias heuristic; defaults from `GITHUB_REF_NAME` when present)
- `CF_PAGES_DEPLOYMENTS_ENVS` (defaults to `production,preview`)

### GitHub Deployments Metadata (fallback; often empty)
Required:
- Repo actually publishes Deployments metadata
- Sufficient permissions (workflow sets `deployments: read`)

## 3) QA Acceptance For “Discovery Works”
Discovery is “working” only when a selected origin returns JSON:
- `GET <BASE_URL>/api/workflow/env-health` -> `200` and `.ok == true`

For Cycle 005 evidence readiness (stronger gate), env-health must also show:
- `.env.NEXT_PUBLIC_SUPABASE_URL == true`
- `.env.SUPABASE_SERVICE_ROLE_KEY == true`

