# Cycle 005 Hosted Persistence Preflight (Cycle #27)

- Repo: junhengz/auto-company
- GHA run: 22011378418
- Run URL: 7:GHA run url: https://github.com/junhengz/auto-company/actions/runs/22011378418
- Result: failed at BASE_URL selection (no deployed workflow runtime origin found)

## Evidence
- Selector stderr: `docs/devops-hightower/cycle-005/hosted-persistence-preflight/latest/evidence/artifacts/run-22011378418/cycle-005-hosted-preflight/select-base-url.err`
- Probe table: `docs/devops-hightower/cycle-005/hosted-persistence-preflight/latest/evidence/artifacts/run-22011378418/cycle-005-hosted-preflight/base-url-probe.txt`

## Key Findings
- All tested `*.vercel.app` candidates returned Vercel `DEPLOYMENT_NOT_FOUND` (HTTP 404).
- `auto-company.pages.dev` returned HTML at `/api/workflow/env-health` (not the Next.js workflow API runtime).
- Several `*.pages.dev` hostnames did not resolve (curl: could not resolve host).

## Immediate Fix
- Identify or deploy the real Next.js workflow runtime origin that serves `GET /api/workflow/env-health` and returns `ok=true` with both env booleans true.
- Then set repo variable `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` and rerun preflight.
