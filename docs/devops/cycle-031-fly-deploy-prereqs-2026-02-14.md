# Cycle 031: Fly Deploy Prereqs (2026-02-14)

## Goal
Deploy `projects/security-questionnaire-autopilot` to Fly (single machine + volume mounted at `/app/runs`) so Cycle 005 can run preflight and persistence evidence against a stable `BASE_URL`.

## Current State (this workstation)
- `flyctl` is installed at `~/.fly/bin/flyctl` but not on PATH by default.
- `flyctl auth whoami` fails with: `No access token available`.

## Required Credential
Provide a Fly API access token (recommended for non-interactive automation):
- Export `FLY_API_TOKEN` in the shell environment used to run deploy scripts.

## One-shot Deploy Helper
Once `FLY_API_TOKEN` is set:

```bash
scripts/devops/deploy-sq-autopilot-fly-and-preflight.sh \
  --repo junhengz/auto-company \
  --preflight-require-supabase-health false
```

This script:
1. Ensures Fly app + volume exist.
2. Deploys using remote builder.
3. Verifies `GET /api/workflow/env-health` returns 200 with required env booleans.
4. Sets `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` to `https://<app>.fly.dev`.
5. Dispatches Cycle 005 preflight-only (no local runtime).

