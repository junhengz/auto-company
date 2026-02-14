# Cycle 005: Deterministic No-Secrets Fallback (Evidence-First)

## Why This Exists

Cycle 005 progress is blocked when Supabase provisioning secrets are unavailable. To keep shipping artifacts anyway, we now have a deterministic fallback that always produces at least one machine-checkable evidence file without needing:

- Supabase Management API credentials
- Supabase project provisioning

## Stage (Ops Diagnosis)

Pre-PMF ops constraint: unblock the weekly “prove migrations are coherent” loop before chasing perfect infra. Evidence beats discussion.

## The Fallback Ladder (No Secrets)

1. **Static bundle verification (always available)**
   - Proves the SQL bundle matches the repo's migration + seed inputs (prevents bundle drift).
   - No Postgres runtime required.

2. **Postgres service apply + verify via GitHub Actions (best-effort)**
   - Applies the bundle to a vanilla Postgres service container and captures `supabase-verify.json`.
   - Still does not require Supabase secrets.
   - Requires: `gh` installed + authenticated and the workflow present on the target repo default branch.

3. **Hosted persistence evidence (optional)**
   - Use when a deployed runtime exists: `scripts/devops/run-cycle-005-hosted-persistence-evidence.sh`.

## How To Run (Operator)

Run the deterministic no-secrets evidence script:

```bash
./scripts/cycle-005/run-no-secrets-evidence.sh --repo junhengz/auto-company
```

Outputs:

- `docs/operations-pg/cycle-005/no-secrets-evidence/latest.json` (manifest)
- `docs/operations-pg/cycle-005/no-secrets-evidence/static/latest.json` (static verify evidence)
- `docs/operations-pg/cycle-005/no-secrets-evidence/gha/latest/supabase-verify.json` (if GHA step succeeded)

## Latest Evidence (This Workspace)

Most recent run manifest:

- `docs/operations-pg/cycle-005/no-secrets-evidence/latest.json`

If you only need a single deterministic artifact to attach to a PR/issue, use:

- `docs/operations-pg/cycle-005/no-secrets-evidence/static/latest.json`

