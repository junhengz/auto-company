# Cycle 005: Static SQL Bundle Evidence (No Postgres Required)

## Purpose

When we cannot run a real Postgres apply (no Supabase secrets, no local Postgres/Docker), we can still produce machine-checkable evidence that:

- the paste-ready Supabase Dashboard SQL bundle is not stale or hand-edited
- it matches the repo's migration + seed inputs deterministically

This reduces the chance we ship a bundle that doesn't correspond to the current schema/version expectations.

## Command

```bash
scripts/devops/run-cycle-005-static-bundle-verify-evidence.sh
```

## Outputs

Primary artifact:

- `docs/devops-hightower/cycle-005/static-bundle-verify/latest.json`

Human-readable verifier output:

- `docs/devops-hightower/cycle-005/static-bundle-verify/verify-stdout-*.txt`

“Green” means `latest.json` has:

- `ok: true`
- `derived.bundle_sha256 == derived.workflow_schema_version.bundleSha256`

