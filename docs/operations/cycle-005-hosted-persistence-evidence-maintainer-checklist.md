# Cycle 005 Hosted Persistence Evidence (Maintainer Checklist)

Goal: make `.github/workflows/cycle-005-hosted-persistence-evidence.yml` produce:
- evidence artifacts (`docs/qa/cycle-005-*.json`, `docs/devops/cycle-005-*.json`)
- a PR that appends to `docs/sales/cycle-003-hosted-workflow-pilot-001-execution.md`

This is intentionally “do things that do not scale”: one correct run proves hosted persistence and unblocks sales proof.

## Stage Diagnosis
- Stage: pre-PMF validation.
- This is an operational blocker, not a product blocker: the workflow is already built; it needs canonical merge + 2 config knobs.

## Maintainer One-Time Setup (15 min)

### 1) Merge workflows into canonical repo
Merge these files into the canonical repo default branch:
- `.github/workflows/cycle-005-hosted-persistence-evidence.yml`
- `.github/workflows/cycle-005-hosted-runtime-env-sync.yml` (optional but recommended)
- `.github/workflows/cycle-005-supabase-apply.yml` (optional)

Safety properties to sanity check in review:
- Scheduled run is gated by repo variable `CYCLE_005_AUTORUN_ENABLED=true` (prevents PR spam).
- Workflow probes candidate origins and refuses marketing/static sites (requires `/api/workflow/env-health`).
- PR branch is stable (`cycle-005-hosted-persistence-evidence`) to avoid infinite PR creation.

### 2) Set the correct deployed BASE_URL candidates
Set repo variable (recommended):
- Variable: `HOSTED_WORKFLOW_BASE_URL_CANDIDATES`
- Value: 2-4 origins (space/comma/newline separated), for the deployed Next.js app that serves `/api/workflow/*`

Option A (GitHub UI):
1. Repo -> Settings -> Secrets and variables -> Actions -> Variables
2. New repository variable
3. Name: `HOSTED_WORKFLOW_BASE_URL_CANDIDATES`
4. Value example:
   - `https://your-app.example.com`
   - `https://your-project.vercel.app`

Option B (`gh` CLI):
```bash
gh variable set HOSTED_WORKFLOW_BASE_URL_CANDIDATES -R OWNER/REPO --body "https://a.example.com https://b.example.com"
```

Hard rule: candidates must return HTTP 200 JSON at:
```bash
curl -sS https://<origin>/api/workflow/env-health | jq .
```

### 3) Ensure hosted runtime has Supabase env vars and redeploy
This config lives on the hosting provider (Vercel/Cloudflare/etc), not in GitHub.

Required env vars on the hosted runtime:
- `NEXT_PUBLIC_SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

Verify after redeploy:
```bash
curl -sS https://<origin>/api/workflow/env-health | jq -r '.ok, .env'
```
Expected:
- `.ok == true`
- `.env.NEXT_PUBLIC_SUPABASE_URL == true`
- `.env.SUPABASE_SERVICE_ROLE_KEY == true`

References:
- `docs/devops/cycle-005-hosted-runtime-env-vars.md`
- `docs/devops/cycle-005-vercel-env-sync-and-redeploy.md` (optional automation)
- `docs/devops/cycle-005-cloudflare-pages-env-sync.md` (optional automation)

## First Run (Preflight) (5 min)

### Option A: run in GitHub Actions UI
1. Actions -> `cycle-005-hosted-persistence-evidence` -> Run workflow
2. Leave `base_url` empty (if you set `HOSTED_WORKFLOW_BASE_URL_CANDIDATES`)
3. Keep defaults unless you know you need SQL apply:
   - `skip_sql_apply`: `true` (default)
4. Keep `preflight_only=true` (default for manual dispatch)

Pass criteria:
- Artifact uploaded:
  - `cycle-005-hosted-preflight`
- No PR is expected in preflight-only mode.

### Option B: run from terminal (preferred if you have `gh` permissions)
```bash
make cycle-005-preflight
```

## Evidence Run (Creates/Updates PR)

After the preflight is green, run again with `preflight_only=false` to create/update the evidence PR.

UI:
1. Actions -> `cycle-005-hosted-persistence-evidence` -> Run workflow
2. Set `preflight_only=false`

CLI:
```bash
make cycle-005-evidence
```

Success criteria:
- Artifacts uploaded:
  - `cycle-005-hosted-preflight`
  - `cycle-005-hosted-persistence-evidence`
- PR created/updated from branch `cycle-005-hosted-persistence-evidence`

## Optional: Bootstrap + Enable Scheduled Refresh (Safe Path)
To bootstrap BASE_URL candidates via best-effort autodiscovery (GitHub Deployments metadata, then hosting APIs) and persist them:
```bash
./scripts/devops/run-cycle-005-hosted-persistence-evidence.sh --repo OWNER/REPO --autodiscover --set-variable --preflight-only
```
If you want the safe maintainer flow (set candidates once, run preflight-only, then enable schedule only after the preflight is green):
```bash
./scripts/devops/run-cycle-005-hosted-persistence-evidence.sh --repo OWNER/REPO \
  --candidates "https://a.example.com https://b.example.com" \
  --set-variable \
  --enable-autorun-after-preflight
```
If you want this to run on schedule afterward:
```bash
./scripts/devops/run-cycle-005-hosted-persistence-evidence.sh --enable-autorun
```

## Common Failure Modes (Actionable)

### Wrong BASE_URL (marketing site)
Symptom: `/api/workflow/env-health` returns 404/HTML.
Fix: update `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` to include the actual Next.js runtime origin.

### Supabase env missing on hosted runtime
Symptom: env-health succeeds but shows env flags false; workflow fails with “configure env vars and redeploy”.
Fix: set `NEXT_PUBLIC_SUPABASE_URL` + `SUPABASE_SERVICE_ROLE_KEY` on hosting provider, then redeploy.

### Schedule runs do nothing
Symptom: scheduled run summary says “skipped (schedule gated)”.
Fix: set repo variable `CYCLE_005_AUTORUN_ENABLED=true` after the first successful manual run.

## Operating Priorities (This Week)
1. Get one successful run and one PR merged (proof of hosted persistence).
2. After success, enable schedule gate to keep evidence fresh (`CYCLE_005_AUTORUN_ENABLED=true`).
3. Only then consider automating provider env sync (Vercel/Cloudflare) if it’s repeatedly failing.
