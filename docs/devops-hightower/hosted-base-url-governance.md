# Hosted BASE_URL Governance (Security Questionnaire Autopilot)

Date: 2026-02-14

## Goal

Make hosted checks deterministic by using **one canonical hosted workflow runtime origin** in CI, instead of scanning/updating a candidate list that can be poisoned by ephemeral tunnel URLs.

## Canonical Variable

GitHub Actions repo variable (single value):

- `HOSTED_WORKFLOW_BASE_URL` = `https://<deployed-nextjs-workflow-runtime-origin>`

Hard rule: this must be the origin that serves `GET /api/workflow/env-health` (the Next.js runtime), not a marketing/static domain.

Deprecated (no longer read by GitHub Actions workflows):

- `HOSTED_WORKFLOW_BASE_URL_CANDIDATES`

## PR-Gating vs Hosted Checks

PR gating (fast, no external dependencies):

- Workflow: `.github/workflows/sq-autopilot-ci.yml`
- Trigger: `pull_request` (paths under `projects/security-questionnaire-autopilot/**`)
- Runs: `npm ci`, `npm run lint`, `npm run typecheck`, `npm run build`
- Does not hit hosted infrastructure.

Hosted integration smoke (scheduled/manual lane):

- Workflow: `.github/workflows/sq-autopilot-hosted-integration.yml`
- Trigger: `schedule` (every 6 hours) and `workflow_dispatch`
- Uses `HOSTED_WORKFLOW_BASE_URL` (or a manual `base_url` override input)
- Runs: `projects/security-questionnaire-autopilot/scripts/smoke-hosted-runtime.sh`

## Cycle 005 Evidence Workflow (Hosted)

Evidence generation still runs in the scheduled/manual lane:

- Workflow: `.github/workflows/cycle-005-hosted-persistence-evidence.yml`
- Schedule is gated by repo variable `CYCLE_005_AUTORUN_ENABLED=true`
- BASE_URL resolution:
  - `workflow_dispatch` input `base_url` (optional override), else
  - repo variable `HOSTED_WORKFLOW_BASE_URL`
- Optional helper input:
  - `persist_hosted_workflow_base_url=true` persists `base_url` into `HOSTED_WORKFLOW_BASE_URL` (after validation/normalization)

## Operator Commands

Set the canonical hosted runtime origin:

```bash
gh variable set HOSTED_WORKFLOW_BASE_URL -R OWNER/REPO --body "https://<runtime-origin>"
```

Run hosted integration smoke now:

```bash
gh workflow run sq-autopilot-hosted-integration.yml -R OWNER/REPO
```

Run Cycle 005 preflight-only now (uses `HOSTED_WORKFLOW_BASE_URL` if `base_url` omitted):

```bash
scripts/devops/run-cycle-005-hosted-persistence-evidence.sh --repo OWNER/REPO --preflight-only
```

