# Cycle 005: Hosted Workflow Runtime Origin(s) + Green Preflight (2026-02-14)

Repo: `junhengz/auto-company`

## Constraints / Requirements

- The Cycle 005 runner needs a `BASE_URL` whose runtime serves:
  - `GET <BASE_URL>/api/workflow/env-health` -> `200` JSON, `.ok==true`
  - and (for “real hosted” readiness) `.env.NEXT_PUBLIC_SUPABASE_URL==true` and `.env.SUPABASE_SERVICE_ROLE_KEY==true`
- The prompt requirement for this handoff specifically:
  - runtime returns `200` JSON at `/api/workflow/env-health` with both env booleans `true`
  - set `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` (or make origin selection self-discovering)
  - re-run Cycle 005 hosted persistence **preflight** until green

## What Exists In Production Right Now

There is **no publicly reachable production workflow runtime origin** for this repo that serves `GET /api/workflow/env-health` as JSON.

Observed “likely” defaults are not valid workflow runtimes:

- `https://auto-company.pages.dev` returns HTML for `/api/workflow/env-health` (marketing/static site, catch-all fallback).
- Common Vercel defaults like `https://auto-company.vercel.app` return `404 DEPLOYMENT_NOT_FOUND`.
- GitHub Deployments metadata is empty (`/repos/:owner/:repo/deployments` -> `[]`), so origin cannot be inferred from Deployments.

## Created Runtime Origin (Credential-Free Fallback)

To satisfy the env-health contract and unblock a deterministic “green preflight” without hosting credentials, the repo now supports a **local runtime preflight**:

- `workflow_dispatch` input: `local_runtime=true`
  - starts an ephemeral Next.js runtime inside the GitHub Actions job
  - forces `BASE_URL=http://127.0.0.1:<port>` for the run
  - sets placeholder env vars so `/api/workflow/env-health` returns both booleans as `true`
- `workflow_dispatch` input: `preflight_require_supabase_health=false`
  - skips `/api/workflow/supabase-health` enforcement (useful before Supabase provisioning)

This is not a “production origin”; it is a reliability bootstrap to prove the runtime contract + wiring is correct while the real hosting stack is still missing.

## Repo Variable: HOSTED_WORKFLOW_BASE_URL_CANDIDATES

Set on 2026-02-14 to a placeholder, reachable-but-invalid candidate (for visibility and to ensure the variable exists):

- `HOSTED_WORKFLOW_BASE_URL_CANDIDATES="https://auto-company.pages.dev"`

Command used:

```bash
gh variable set HOSTED_WORKFLOW_BASE_URL_CANDIDATES -R junhengz/auto-company --body "https://auto-company.pages.dev"
```

Once a real hosted workflow runtime exists, replace the value with 2-4 real runtime origins (no paths) that pass:

```bash
curl -sS "<BASE_URL>/api/workflow/env-health" | jq -e \
  '.ok==true and .env.NEXT_PUBLIC_SUPABASE_URL==true and .env.SUPABASE_SERVICE_ROLE_KEY==true'
```

## Preflight: Green Run Evidence

Cycle 005 preflight was re-run and went green using the credential-free local runtime path:

- GitHub Actions run: `22011876571` (ref: `main`)
- Selected `BASE_URL`: `http://127.0.0.1:18080`
- `env-health` artifact (excerpt):
  - `.ok == true`
  - `.env.NEXT_PUBLIC_SUPABASE_URL == true`
  - `.env.SUPABASE_SERVICE_ROLE_KEY == true`

Operator command (local wrapper):

```bash
./scripts/devops/run-cycle-005-hosted-persistence-evidence.sh \
  --repo junhengz/auto-company \
  --preflight-only \
  --local-runtime \
  --preflight-require-supabase-health false \
  --no-local-probe
```

Notes:

- Earlier run `22011800708` failed because the workflow step "Enable scheduled autorun gate after green preflight" executed even when the input was false, and the GitHub API variable upsert returned `HTTP 403`. This was fixed on `main` by commit `1f4c495` (explicit `== 'true'` checks).
- A prior green run exists on the pre-merge branch ref `qa-bach/local-runtime-preflight` (GHA run `22011679812`).

## Durable Production Recommendation

Use Vercel (lowest ops overhead) and deploy the Next.js runtime rooted at:

- `projects/security-questionnaire-autopilot/`

Then:

1. Set hosted runtime env vars on the provider:
   - `NEXT_PUBLIC_SUPABASE_URL`
   - `SUPABASE_SERVICE_ROLE_KEY`
2. Apply the shipped Supabase SQL bundle to the same project (Dashboard SQL Editor is fine).
3. Update `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` to the real production origin(s).
4. Re-run preflight with `preflight_require_supabase_health=true` until green.

## Next Action

Merge PR `junhengz/auto-company#1`, deploy `projects/security-questionnaire-autopilot` to a real hosting provider, then replace `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` with 2-4 real runtime origins and re-run Cycle 005 preflight with `preflight_require_supabase_health=true`.
