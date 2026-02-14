# Cycle 002: Canonical Hosted Base URL Governance (2026-02-14)

## Goal
Make Cycle 005 preflight/evidence deterministic by using **one canonical hosted runtime origin** and refusing to operate on ephemeral tunnel domains.

## Contract (Single Source of Truth)
- Repo variable: `HOSTED_WORKFLOW_BASE_URL`
  - Value: a single origin (no path), e.g. `https://auto-company-sq-autopilot.fly.dev`
  - Must serve: `GET /api/workflow/env-health` (200 JSON with `ok=true`)

## What Changed
- `.github/workflows/cycle-005-hosted-persistence-evidence.yml`
  - Added input `persist_hosted_workflow_base_url` (workflow_dispatch).
  - Added a step to persist `base_url` into repo variable `HOSTED_WORKFLOW_BASE_URL` (with tunnel-origin guardrail).
  - Added a guardrail in BASE_URL resolution to refuse disallowed tunnel origins.
- `.github/workflows/sq-autopilot-ci.yml`
  - PR/push CI lane for `projects/security-questionnaire-autopilot` (lint/typecheck/build).
  - Does not touch hosted infra.
- `.github/workflows/sq-autopilot-hosted-integration.yml`
  - Scheduled/manual hosted smoke checks (env-health and optional supabase-health) against `HOSTED_WORKFLOW_BASE_URL`.
- `scripts/devops/run-cycle-005-hosted-persistence-evidence.sh`
  - Operator wrapper now targets the canonical variable and workflow input (`persist_hosted_workflow_base_url`).
  - Explicitly does not support candidate scanning (`HOSTED_WORKFLOW_BASE_URL_CANDIDATES`) by design.
- `scripts/devops/deploy-sq-autopilot-fly-and-preflight.sh`
  - Now persists `HOSTED_WORKFLOW_BASE_URL` (not the legacy candidates variable).
- `scripts/devops/gh-delete-hosted-workflow-base-url-candidates.sh`
  - Now deletes `HOSTED_WORKFLOW_BASE_URL` (and best-effort deletes legacy `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` if present).
- `projects/security-questionnaire-autopilot/scripts/select-hosted-base-url.sh`
  - Now recognizes `HOSTED_WORKFLOW_BASE_URL` as a candidate source.

## Operator Runbook
1. Set the canonical origin once:
   - `gh variable set HOSTED_WORKFLOW_BASE_URL -R OWNER/REPO --body "https://<your-runtime-origin>"`
2. Run Cycle 005 preflight only:
   - `scripts/devops/run-cycle-005-hosted-persistence-evidence.sh --repo OWNER/REPO --preflight-only`
3. Optional: if you cannot edit repo variables directly, persist via workflow dispatch:
   - `scripts/devops/run-cycle-005-hosted-persistence-evidence.sh --repo OWNER/REPO --base-url "https://<your-runtime-origin>" --persist-hosted-base-url --preflight-only`

## Next Action
Ensure the canonical repo (owner + secrets/vars) is clear, then deploy the runtime to a stable host and set `HOSTED_WORKFLOW_BASE_URL` to that origin.
