# Cycle 005: Postgres Service Apply + Verify (Evidence Directory)

This directory is owned by the `devops-hightower` role and is intended to store:

- workflow dispatch evidence
- artifact fetch evidence
- extracted `supabase-verify.json` results

Primary entrypoint:

```bash
scripts/devops/run-cycle-005-fallback-postgres-service-evidence.sh --repo <OWNER/REPO>
```

## Known Blocker (As Of 2026-02-14)

If the workflow is not present on the repo's default branch, dispatch will 404 and the wrapper will emit an error JSON:

- `workflow-missing-on-remote-*.json`

Fix:

- merge `.github/workflows/cycle-005-postgres-service-apply-verify.yml` to the repo default branch

