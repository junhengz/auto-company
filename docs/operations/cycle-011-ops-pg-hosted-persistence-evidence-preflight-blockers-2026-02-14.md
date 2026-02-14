# Cycle 011 (Operations/PG): Cycle-005 Preflight Blockers (2026-02-14)

## Preflight Attempt (Local Wrapper)
Command executed:
```bash
./scripts/devops/run-cycle-005-hosted-persistence-evidence.sh --repo "junhengz/auto-company" --preflight-only --autodiscover --no-local-probe
```

Result: **blocked before dispatch**.

### Blocking Error
- `Missing BASE_URL candidates.`

Meaning:
- No workflow-runtime origins were provided via:
  - workflow input (`--base-url ...`), or
  - repo variable `HOSTED_WORKFLOW_BASE_URL_CANDIDATES`, and
  - autodiscovery found nothing (no Deployments metadata, no provider API creds configured locally).

### What Inputs Are Missing (Minimum)
One of:
1. `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` repo variable set to 2-4 deployed origins, or
2. Run with `--base-url "https://candidate1 https://candidate2"`.

Optional (to make autodiscovery work):
- Vercel discovery:
  - `VERCEL_TOKEN` + (`VERCEL_PROJECT_ID` or `VERCEL_PROJECT`) [+ `VERCEL_TEAM_ID`/`VERCEL_TEAM_SLUG`]
- Cloudflare Pages discovery:
  - `CLOUDFLARE_API_TOKEN` + `CLOUDFLARE_ACCOUNT_ID` + `CF_PAGES_PROJECT`

## Extra Risk Flag (Canonical Repo Gap)
`nicepkg/auto-company` currently reports **0 GitHub Actions workflows** via the Actions Workflows API.
Practical impact: you cannot run Cycle-005 evidence/preflight there until the workflow files are present on the default branch.

