# Cycle 005 (DevOps-Hightower): No-Secrets Evidence Paths

## Current Status (2026-02-14)

- Supabase provisioning secrets are missing, so provisioning/apply workflows that require the Supabase Management API are blocked.
- Local Postgres/Docker are not available in this environment, so we cannot do a true local apply+verify run.

## Evidence Paths

1. Static bundle verification (always available):
   - Run: `scripts/devops/run-cycle-005-static-bundle-verify-evidence.sh`
   - Latest: `docs/devops-hightower/cycle-005/static-bundle-verify/latest.json`

2. Postgres service apply+verify (requires workflow merged to remote default branch):
   - Run: `scripts/devops/run-cycle-005-fallback-postgres-service-evidence.sh --repo <OWNER/REPO>`
   - Docs: `docs/devops-hightower/cycle-005-fallback-postgres-service.md`

