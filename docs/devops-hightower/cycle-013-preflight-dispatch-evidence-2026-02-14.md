# Cycle 013: Preflight Dispatch Evidence (2026-02-14)

This is a concrete dispatch run demonstrating the hosted BASE_URL preflight failure mode is **deterministic** (red) and produces actionable artifacts.

## Command Used

This repo's operator wrapper needs `--ref` when the workflow file is not present on the target repo's default branch.

```bash
./scripts/devops/run-cycle-005-hosted-persistence-evidence.sh \
  --repo junhengz/auto-company \
  --ref cycle-008-hosting-discovery-v2 \
  --preflight-only \
  --no-local-probe \
  --base-url "https://auto-company.vercel.app https://auto-company-hosted.vercel.app"
```

## Run

- repo: `junhengz/auto-company`
- workflow: `cycle-005-hosted-persistence-evidence`
- ref: `cycle-008-hosting-discovery-v2`
- run databaseId: `22008876104`
- run url: `https://github.com/junhengz/auto-company/actions/runs/22008876104`
- result: **failure** at step `Select + validate deployed BASE_URL (fail-fast)`

## Expected Failure Reason (Why This Run Is Red)

The candidate origins used above do not resolve to a deployed workflow runtime that serves:

- `GET /api/workflow/env-health` (200 JSON, `.ok==true`)

In this case, Vercel returns `DEPLOYMENT_NOT_FOUND` and no valid runtime is selected.

## Artifacts Produced (What A Maintainer Should Look At)

Even on failure, the workflow uploads:

- `cycle-005-hosted-base-url-probe`
  - `preflight/base-url-candidates.txt`
  - `preflight/base-url-source.txt`
  - `preflight/base-url-probe.txt`
- `cycle-005-hosted-preflight`
  - includes probe artifacts plus selector stderr (`preflight/select-base-url.err`) and any captured `env-health.json` / `supabase-health.json` when available

## Determinism Claim (What This Proves)

- If there are no candidates, manual runs fail fast (not a false green).
- If candidates exist but do not map to the workflow runtime, selection fails fast with a probe table and selector stderr.
- The preflight artifacts are always uploaded so diagnosis does not require rerunning with ad-hoc logging.

