# Cycle 005: Supabase Provision/Apply/Verify Unblock (CTO)

## Constraints
- Repo with admin: `junhengz/auto-company`
- Repo with read-only: `nicepkg/auto-company`
- Cycle 005 provisioning workflow requires GitHub Actions repo secrets (names):
  - `SUPABASE_ACCESS_TOKEN`
  - `SUPABASE_ORG_SLUG`
  - `SUPABASE_DB_PASSWORD`

## Current Blocker (as of 2026-02-14)
- In `junhengz/auto-company`, the three required secrets are missing.
- Evidence: `docs/devops/evidence/actions-secrets-check-junhengz_auto-company-20260214T033157Z-402190-21478.json`

This causes the provision/apply job to fail before apply, and the workflow only uploads the safe fallback `supabase-verify.json` with `ok=false`.

## Decisive Next Steps To Get `ok=true supabase-verify.json`
1. Obtain/create a Supabase Management API token that can create/list projects in the target org.
2. Decide org slug and a strong DB password for the provisioned project.
3. Set the 3 GitHub repo secrets in `junhengz/auto-company`:
   - `SUPABASE_ACCESS_TOKEN` (secret)
   - `SUPABASE_ORG_SLUG` (not secret but treat as config)
   - `SUPABASE_DB_PASSWORD` (secret)

4. Dispatch the workflow and collect artifacts using the shipped non-interactive CTO wrapper (writes evidence under `docs/cto/`):

```bash
cd /home/zjohn/autocomp/auto-company

export GH_TOKEN="***"  # PAT with repo + workflow scope for junhengz/auto-company
export SUPABASE_ACCESS_TOKEN="***"
export SUPABASE_ORG_SLUG="your-org-slug"
export SUPABASE_DB_PASSWORD="***"

scripts/devops/run-cycle-018-supabase-ci-cto.sh \
  --repo junhengz/auto-company \
  --set-missing \
  --non-interactive
```

5. Machine-check success from the downloaded artifact:

```bash
jq -e '.ok == true' docs/cto/cycle-018-supabase-ci/runs/*/supabase-verify.json
```

Pass criteria: at least one run directory contains `supabase-verify.json` with `.ok == true`.

## Failure Modes To Expect (and Fast Triage)
- `missing_required_secrets`: secrets not set, or workflow executed in a context that cannot access them.
- Provision fails with org policy errors (often region selection): set `SUPABASE_REGION_SELECTION_JSON` as a repo secret if your Supabase org requires it.
- `Multiple Supabase projects found matching name=...`: pick a unique `supabase_project_name` for the dispatch input, or delete/rename duplicates.
- Provision timeout: increase `SUPABASE_PROVISION_TIMEOUT_SECONDS` if you run into slow project activation.

## Minimal Workflow Change Applied
- Both Cycle 005 provision/apply workflows now write a more informative fallback `projects/security-questionnaire-autopilot/runs/supabase-verify.json` when earlier steps fail (still non-secret), including `reason`, `project_ref` (if available), workflow inputs, and GitHub run metadata.
  - `.github/workflows/cycle-005-supabase-provision-apply-verify.yml`
  - `.github/workflows/cycle-005-supabase-provision-apply-verify-dispatch.yml`

