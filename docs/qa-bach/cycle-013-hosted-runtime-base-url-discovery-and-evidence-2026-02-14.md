# Cycle 013 (qa-bach): Unblock Hosted Runtime BASE_URL Discovery + Evidence Preflight

Date: 2026-02-14
Branch: `cycle-008-hosting-discovery-v2`

## What This Cycle Needed

Make hosted `BASE_URL` discovery deterministic enough that a maintainer can:

1. Provide 2-4 candidate origins (from hosting provider UI or API).
2. Run a preflight that reliably selects the correct Next.js runtime by probing `GET <BASE_URL>/api/workflow/env-health`.
3. Persist candidates for repeat runs via repo variable `HOSTED_WORKFLOW_BASE_URL_CANDIDATES`.

## Primary Blocker Found (and Fixed)

### Symptom

GitHub Actions preflight failed during:

- Step: `Select + validate deployed BASE_URL (fail-fast)`
- Error: `.../projects/projects/security-questionnaire-autopilot/scripts/discover-hosted-base-url.sh: No such file or directory`

Evidence:

- `docs/qa-bach/cycle-013-gha-preflight-run-22008924579-2026-02-14/preflight/select-base-url.err`
- (older run) `docs/qa-bach/cycle-013-gha-preflight-run-22008876104-2026-02-14/preflight/select-base-url.err`

### Root Cause

Several scripts located under `projects/security-questionnaire-autopilot/scripts/` computed `ROOT` as:

`$(dirname ...)/../..`

That resolves to `projects/security-questionnaire-autopilot/` (project root), not the repo root, which then produced broken paths like:

`.../projects/projects/security-questionnaire-autopilot/...`

### Fix (Committed + Pushed)

Commit: `c69eac5` on `junhengz/auto-company:cycle-008-hosting-discovery-v2`

Files updated to compute repo root correctly (`../../..`) and unblock discovery + runner execution:

- `projects/security-questionnaire-autopilot/scripts/collect-base-url-candidates-from-hosting.sh`
- `projects/security-questionnaire-autopilot/scripts/select-hosted-base-url.sh`
- `projects/security-questionnaire-autopilot/scripts/smoke-hosted-runtime.sh`
- `projects/security-questionnaire-autopilot/scripts/hosted-workflow-customer-intake.sh`
- `projects/security-questionnaire-autopilot/scripts/cycle-005-hosted-supabase-apply-and-run.sh`

Also updated:

- `scripts/devops/run-cycle-005-hosted-persistence-evidence.sh`

## Evidence Generated (Determinism Proof)

### 1) Local Script Selftest (Mock Runtimes)

Demonstrates deterministic selection rules (JSON vs HTML; env-required vs allow-missing-env):

- `docs/qa-bach/cycle-013-hosted-base-url-discovery-local-selftest-2026-02-14.txt`

### 2) GHA Preflight Evidence (Invalid Candidate)

Demonstrates failure mode is now the intended one (candidate rejected by env-health probe), not a path bug:

- Run: `22008955940` (fork repo, `workflow_dispatch`, `base_url=https://example.com`)
- Artifacts:
  - `docs/qa-bach/cycle-013-gha-preflight-run-22008955940-2026-02-14/preflight/base-url-probe.txt`
  - `docs/qa-bach/cycle-013-gha-preflight-run-22008955940-2026-02-14/preflight/select-base-url.err`

## Remaining Risk / Unknowns (Still Blocks “Green”)

- We still need real deployed hosted runtime origins (2-4) from the actual hosting provider (Vercel/Pages/etc).
- If the correct runtime is found but `env-health` reports missing env vars, the maintainer must set:
  - `NEXT_PUBLIC_SUPABASE_URL`
  - `SUPABASE_SERVICE_ROLE_KEY`
  then redeploy.

## Recommended Maintainer Flow (Minimal)

1. Set `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` to 2-4 real origins (no paths).
2. Dispatch `cycle-005-hosted-persistence-evidence.yml` with `preflight_only=true`.
3. When green, re-run with `preflight_only=false` to generate the evidence PR.

See also:

- `docs/devops/base-url-discovery.md`
- `docs/operations/cycle-008-maintainer-one-shot.md`

