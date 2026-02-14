# Cycle 011: Hosted Runtime Discovery Runbook (DevOps-Hightower)

Goal: produce 2-4 authoritative `BASE_URL` candidates for the deployed Next.js runtime that serves `GET /api/workflow/env-health`, then set `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` so Cycle 005 preflight can run without human guessing.

## 0) Reality Check: Is This Merged Into The Canonical Repo?

Canonical repo in this workspace: `nicepkg/auto-company` (git remote `origin`).

Today (2026-02-14), `origin/main` does **not** contain:

- `.github/workflows/cycle-005-hosted-persistence-evidence.yml`
- `projects/security-questionnaire-autopilot/scripts/select-hosted-base-url.sh`
- `projects/security-questionnaire-autopilot/scripts/collect-base-url-candidates-from-*-api.sh`

So you cannot run the Cycle 005 preflight against `nicepkg/auto-company` until a PR merges those files.

## 1) Merge The Runtime Discovery + Evidence Workflow (Required)

Create a PR from the fork branch that contains the workflow + discovery scripts:

```bash
gh pr create -R nicepkg/auto-company \
  --head junhengz:cycle-008-hosting-discovery-v2 \
  --base main \
  --title "Cycle 005: hosted persistence evidence workflow + runtime BASE_URL autodiscovery" \
  --body "Adds Cycle 005 hosted persistence evidence workflow + hosting-provider BASE_URL autodiscovery (Vercel + Cloudflare Pages)."
```

After merge, verify the workflow exists:

```bash
gh workflow list -R nicepkg/auto-company | rg -n "cycle-005-hosted-persistence-evidence"
```

## 2) Choose Discovery Mode (Minimal Inputs)

Fastest path (lowest config burden): set explicit candidates once.

```bash
gh variable set HOSTED_WORKFLOW_BASE_URL_CANDIDATES -R nicepkg/auto-company \
  --body "https://<candidate1> https://<candidate2> https://<candidate3>"
```

Provider-first autodiscovery (no human guessing) requires provider creds:

- Vercel discovery:
  - Secret: `VERCEL_TOKEN`
  - Variable: `VERCEL_PROJECT_ID` (preferred) or `VERCEL_PROJECT`
  - Optional vars: `VERCEL_TEAM_ID`, `VERCEL_TEAM_SLUG`
- Cloudflare Pages discovery:
  - Secret: `CLOUDFLARE_API_TOKEN`
  - Variables: `CLOUDFLARE_ACCOUNT_ID`, `CF_PAGES_PROJECT`
  - Optional vars: `CF_PAGES_BRANCH`, `CF_PAGES_DEPLOYMENTS_LIMIT`, `CF_PAGES_DEPLOYMENTS_ENVS`

## 3) Run Preflight Only (Read-Only Signal)

Dispatch preflight:

```bash
gh workflow run cycle-005-hosted-persistence-evidence.yml -R nicepkg/auto-company \
  -f preflight_only=true \
  -f skip_sql_apply=true
```

If you cannot set repo variables directly, you can persist candidates from the workflow dispatch:

```bash
gh workflow run cycle-005-hosted-persistence-evidence.yml -R nicepkg/auto-company \
  -f preflight_only=true \
  -f skip_sql_apply=true \
  -f persist_base_url_candidates=true \
  -f base_url="https://<candidate1> https://<candidate2>"
```

## 4) What “Green” Means

Green preflight requires:

- A reachable runtime `BASE_URL` such that:
  - `GET <BASE_URL>/api/workflow/env-health` returns JSON with `ok=true`
  - and (for evidence readiness) `env.NEXT_PUBLIC_SUPABASE_URL=true` and `env.SUPABASE_SERVICE_ROLE_KEY=true`

If hosted env vars are missing, the workflow may attempt best-effort auto-fix:

- Vercel: upsert + redeploy (requires `VERCEL_TOKEN` and Supabase secrets)
- Cloudflare Pages: upsert (redeploy may still require manual trigger unless deploy hook is configured)

