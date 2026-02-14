# Cycle 031: Reset Broken Hosted BASE_URL Variable (2026-02-14)

## Summary
`junhengz/auto-company` had a stale/ephemeral `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` value that caused Cycle 005 preflight-only runs to fail during BASE_URL selection.

## What Happened
1. A preflight-only dispatch was triggered against `HOSTED_WORKFLOW_BASE_URL_CANDIDATES=https://256a110fe2b963.lhr.life`.
2. The run failed at `Select + validate deployed BASE_URL (fail-fast)` because `/api/workflow/env-health` returned `HTTP 503`.

Evidence:
- GHA run: `22012361781` (failed)
- Failure: `https://256a110fe2b963.lhr.life -> env-health HTTP 503`

## Action Taken
Deleted the poisoned repo variable on `junhengz/auto-company`:
- `HOSTED_WORKFLOW_BASE_URL_CANDIDATES`

This forces future runs to either:
- use explicitly provided `--base-url` / `--candidates`, or
- set a new stable repo variable value (recommended once a real deployment exists).

Note:
- The variable was later observed re-introduced with another ephemeral origin (`*.loca.lt`) and deleted again.
  Use `scripts/devops/gh-delete-hosted-workflow-base-url-candidates.sh` to keep it clean until a stable origin exists.

## Next Action
Provision a stable hosted workflow runtime origin (Fly preferred, with volume mounted to `/app/runs`), then set:

```bash
gh variable set HOSTED_WORKFLOW_BASE_URL_CANDIDATES -R "junhengz/auto-company" --body \
  "https://<stable-origin-1> https://<stable-origin-2>"
```
