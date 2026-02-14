# Cycle 003: Hosted Preflight Baseline (Fork) - 2026-02-14

## Goal
Establish a repeatable green baseline for Cycle 005 preflight checks even while the canonical hosted origin is not yet deployed.

## What We Found
- Canonical upstream repo `nicepkg/auto-company` is readable from the current GitHub CLI identity (`junhengz`), but not writable (permission: READ).
- The intended Fly origin `https://auto-company-sq-autopilot.fly.dev` currently returns NXDOMAIN (not deployed / app not created).

## What We Did (Concrete)
Repo: `junhengz/auto-company`

1. Set repo variables (so both old and new selection paths have a stable value):
   - `HOSTED_WORKFLOW_BASE_URL=https://auto-company-sq-autopilot.fly.dev`
   - `HOSTED_WORKFLOW_BASE_URL_CANDIDATES=https://auto-company-sq-autopilot.fly.dev`

2. Dispatched a preflight-only run using the workflow's `local_runtime=true` fallback:
   - Workflow: `cycle-005-hosted-persistence-evidence`
   - Run ID: `22013120396`
   - Inputs (not exhaustive):
     - `local_runtime=true`
     - `preflight_only=true`
     - `skip_sql_apply=true`
     - `preflight_require_supabase_health=false`

Result: green run (validated runtime contract + `env-health` without requiring external hosting/Supabase).

## Why This Matters
This creates an immediate "green baseline" signal in CI while we unblock the real hosted runtime and its secrets/credentials surface.

## Next Action
Deploy a real hosted runtime to a stable origin (Fly preferred), then re-run `cycle-005-hosted-persistence-evidence` with `local_runtime=false` and `preflight_require_supabase_health=true`.

