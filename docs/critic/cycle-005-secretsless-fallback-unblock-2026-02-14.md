# Cycle 005 Secretsless Fallback Unblock (2026-02-14)

## Verdict: support (as a stopgap for artifact continuity), not proof of Supabase readiness

This change is worth shipping because it prevents Cycle 005 from stalling when Supabase provisioning secrets are missing. It does **not** eliminate the need for a real Supabase apply-and-verify run; it just ensures we can keep producing deterministic, machine-checkable artifacts.

## Key Risks / Potential Fatal Flaws

- **False confidence risk:** a vanilla Postgres service container is not Supabase. Passing apply+verify there does not guarantee Supabase compatibility (extensions, roles, RLS behavior, Supabase-provided schemas).
- **Evidence ambiguity risk:** artifacts are still named `cycle-005-supabase-provision-apply-verify`; without an explicit marker, people will misread “fallback Postgres apply” as “Supabase apply.” Mitigation shipped: `projects/security-questionnaire-autopilot/runs/cycle-005-apply-path.txt` is now always uploaded and extracted.
- **Operational brittleness:** the stronger fallback depends on GitHub Actions being enabled and the patched workflow being merged to the target repo default branch. If Actions are disabled or the patch isn’t merged, you drop back to static verification only.

## Concrete Failure Scenarios (Inversion)

1. **“Green fallback” but real Supabase fails:**
   - SQL depends on Supabase extensions or default roles/policies that don’t exist on vanilla Postgres; fallback stays green and we ship broken infra assumptions.
2. **Misinterpretation by downstream operator:**
   - Someone sees `supabase-verify.json` and assumes provisioning succeeded; they proceed to set hosted runtime env vars using a non-existent project ref. The apply-path marker is the guardrail; if it’s ignored, this fails.
3. **Workflow remains stuck on the target repo:**
   - The fallback only works after `.github/workflows/cycle-005-supabase-provision-apply-verify(-dispatch).yml` is updated on the repo default branch. Until then, GHA runs can still fail hard on missing secrets.

## What Shipped (Concrete)

- Secrets-aware deterministic fallback in existing workflows (no new workflow file required):
  - `.github/workflows/cycle-005-supabase-provision-apply-verify-dispatch.yml`
  - `.github/workflows/cycle-005-supabase-provision-apply-verify.yml`
  - Behavior: if required Supabase secrets are missing, run `postgres:15` service-container apply+verify and still upload `supabase-verify.json` plus `cycle-005-apply-path.txt`.
- Fixed the “no-secrets” GHA step to dispatch a workflow that exists on `junhengz/auto-company`:
  - `scripts/devops/run-cycle-005-fallback-postgres-service-evidence.sh` now dispatches `cycle-005-supabase-provision-apply-verify-dispatch.yml` and downloads artifact `cycle-005-supabase-provision-apply-verify`.
- Reduced evidence ambiguity:
  - `scripts/devops/gha-run-fetch-artifacts.sh` now extracts `cycle-005-apply-path.txt` into `docs/**/evidence/cycle-005-apply-path-run-<id>.txt` when present.
- Always-works local fallback (no `gh`):
  - `make cycle-005-fallback` runs `scripts/devops/run-cycle-005-static-bundle-verify-evidence.sh`.

## New Machine-Checkable Evidence (This Workspace)

- Manifest (machine-checkable): `docs/critic/cycle-005/no-secrets-evidence/latest.json`
- Static bundle verification evidence: `docs/critic/cycle-005/no-secrets-evidence/static/latest.json`

## Next Action

Merge the workflow fallback changes to `junhengz/auto-company` default branch, then run:

```bash
./scripts/cycle-005/run-no-secrets-evidence.sh --repo junhengz/auto-company
```

