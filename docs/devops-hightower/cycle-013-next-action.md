# Next Action (Cycle 013)

1. Merge PR #3 (`cycle-008-hosting-discovery-v2`) into `nicepkg/auto-company:main` so the canonical repo contains:
   - `.github/workflows/cycle-005-hosted-persistence-evidence.yml`
   - hosting candidate discovery scripts under `projects/security-questionnaire-autopilot/scripts/`
2. Set `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` (2-4 real origins from the hosting provider UI; must pass `GET /api/workflow/env-health`).
3. Run one manual dispatch with `preflight_only=true` (confirm `has_supabase_env=true`).
4. Fix hosted runtime env vars (if needed) on the hosting provider and redeploy until preflight is green.
5. Re-run with `preflight_only=false` to generate the evidence PR (branch `cycle-005-hosted-persistence-evidence`).

