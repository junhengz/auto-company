# Next Action

## Cycle 005 (Supabase provision/apply/verify)

1) Produce Cycle 005 evidence without any Supabase secrets (deterministic fallback):

```bash
./scripts/cycle-005/run-no-secrets-evidence.sh --repo junhengz/auto-company
```

Read:

- `docs/operations-pg/cycle-005/no-secrets-evidence/latest.json`
- `docs/operations-pg/cycle-005/no-secrets-evidence/static/latest.json`

Runbook: `docs/operations-pg/cycle-005-no-secrets-fallback-2026-02-14.md`

If you need a fully local, always-works (no `gh`) fallback, run the static verifier only:

```bash
make cycle-005-fallback
```

2) (When secrets exist) verify required secrets are missing/present (names only):

```bash
./scripts/devops/gha-secrets-verify.sh --repo junhengz/auto-company
```

3) (When secrets exist) set the 3 required secrets (prompts, no echo):

```bash
./scripts/devops/gha-secrets-set.sh --repo junhengz/auto-company
```

4) (When secrets exist) dispatch the workflow and download artifacts:

```bash
./scripts/devops/run-cycle-005-supabase-provision-apply-verify.sh --repo junhengz/auto-company
```

Runbook: `docs/operations-pg/cycle-005-supabase-gha-secrets-unblock-2026-02-14.md`

## Cycle 018 (Supabase CI)

Run the scripted end-to-end Supabase CI workflow dispatch (prompts for missing secret values, no echo):

```bash
./scripts/ops/cycle-018-supabase-ci.sh all --prompt
```

Then open the newest `docs/operations-pg/cycle-018-supabase-ci/run-*/supabase-verify.json` and proceed based on `.ok`.
