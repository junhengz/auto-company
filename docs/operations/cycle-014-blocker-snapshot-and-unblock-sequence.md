# Cycle 014 Ops Snapshot: Blockers And Unblock Sequence

Date: 2026-02-14

Project: Security Questionnaire Autopilot

Repo:
- `junhengz/security-questionnaire-autopilot`
- `/home/zjohn/autocomp/security-questionnaire-autopilot`

## Current Blockers (Concrete)

1. No deployed BASE_URL for the hosted workflow runtime.
   - GitHub Deployments discovery returns none for this repo.
2. Cycle 005 preflight requires Supabase connectivity and schema+seed validation via:
   - `/api/workflow/supabase-health?requireSeed=1&requirePilotDeals=1`
   - This cannot pass without a real Supabase project + applied bundle.
3. No provider automation credentials are present in the local environment.

## Minimum Unblock Sequence (Fastest Path)

1. Create Supabase project (or identify existing one):
   - Capture:
     - `NEXT_PUBLIC_SUPABASE_URL`
     - `SUPABASE_SERVICE_ROLE_KEY`
     - `SUPABASE_DB_URL` (only needed for automated SQL apply; dashboard apply can avoid this)
2. Apply SQL bundle:
   - `projects/security-questionnaire-autopilot/supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql`
3. Deploy hosted runtime:
   - Prefer Vercel for Next.js App Router + API routes.
4. Configure hosting env vars and redeploy:
   - `NEXT_PUBLIC_SUPABASE_URL`
   - `SUPABASE_SERVICE_ROLE_KEY`
5. Set deterministic BASE_URL candidates in GitHub repo var:
   - `HOSTED_WORKFLOW_BASE_URL_CANDIDATES="https://... https://..."`
6. Run Cycle 005 preflight until green:
   - Workflow: `cycle-005-hosted-persistence-evidence` with `preflight_only=true`
7. Run full evidence:
   - `preflight_only=false` to generate PR with evidence artifacts.

## Next Action

Assign an owner to provision Supabase + deploy Vercel, then record the resulting BASE_URL and set `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` so Cycle 005 can run without manual URL guessing.
