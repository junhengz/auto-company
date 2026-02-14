# Cycle 011: Hosted Persistence Evidence Preflight (Blockers) (QA-Bach)

Date (UTC): 2026-02-14  
Target workflow: `.github/workflows/cycle-005-hosted-persistence-evidence.yml` (preflight_only=true)

## What I Ran (Local Operator Wrapper)

1) Preflight-only dispatch attempt (no candidates provided):
```bash
./scripts/devops/run-cycle-005-hosted-persistence-evidence.sh --preflight-only
```

Observed failure (hard blocker):
- Cannot read repo vars (HTTP 403) and no candidates provided, so it fails fast with `Missing BASE_URL candidates.`

2) Preflight-only dispatch attempt with explicit candidate and local probing disabled:
```bash
./scripts/devops/run-cycle-005-hosted-persistence-evidence.sh \
  --preflight-only \
  --no-local-probe \
  --base-url "https://auto-company.pages.dev"
```

Observed failure (hard blocker):
- GitHub API returns `HTTP 404: Not Found` for the workflow path:
  - `https://api.github.com/repos/nicepkg/auto-company/actions/workflows/cycle-005-hosted-persistence-evidence.yml`

Interpretation:
- Upstream repo `nicepkg/auto-company` `main` currently has **no GitHub Actions workflows**, so there is nothing to dispatch yet.

## Current Upstream State (Why Preflight Cannot Run)

Upstream `nicepkg/auto-company`:
- Default branch: `main`
- Viewer permission from this environment: `READ`
- Actions workflows list is empty: `{ total_count: 0, workflows: [] }`
- PRs are open (not merged):
  - PR #1: Cycle 005 env sync + evidence workflow
  - PR #2: Cycle 005 preflight-first hosted evidence workflow
  - PR #3: Cycle 008 expand hosted BASE_URL autodiscovery

## Blocking Issues (Ranked)

1) **Workflow not present in upstream `main`**
   - Until PR #2 (and dependencies) land, `cycle-005-hosted-persistence-evidence` cannot be dispatched on upstream.

2) **No authoritative hosted workflow-runtime origin(s)**
   - Probing known guesses still fails:
     - `*.vercel.app` candidates return `DEPLOYMENT_NOT_FOUND` (HTTP 404)
     - `security-questionnaire-autopilot*.pages.dev` candidates do not resolve (DNS)
     - `https://auto-company.pages.dev` returns HTML (not the workflow runtime; `/api/workflow/env-health` is not JSON)

3) **Operator cannot read repo variables/secrets from CLI (HTTP 403)**
   - Not fatal if you can pass `--base-url`/`--candidates` and dispatch from an account with `WRITE+`.
   - But it blocks “no-input” runs and local validation of configuration state.

## What “Unblocked” Looks Like (Concrete)

1) Merge PR #2 and PR #3 into `nicepkg/auto-company:main` (so workflows exist upstream).
2) Set repo variable:
   - `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` = `2-4` real workflow-runtime origins
3) Run manual workflow dispatch:
   - `cycle-005-hosted-persistence-evidence` with `preflight_only=true` (default)
4) Only after a green preflight:
   - set `CYCLE_005_AUTORUN_ENABLED=true` (or use `enable_autorun_after_preflight=true`)

