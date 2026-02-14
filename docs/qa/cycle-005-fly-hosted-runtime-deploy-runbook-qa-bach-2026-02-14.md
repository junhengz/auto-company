Date: 2026-02-14
Role: qa-bach

# Goal

Deploy `projects/security-questionnaire-autopilot` to Fly app `auto-company-sq-autopilot` so:

- `https://auto-company-sq-autopilot.fly.dev` is reachable
- `GET /api/workflow/env-health` returns `200` JSON with required env booleans `true`
- `GET /api/workflow/supabase-health` returns `.ok == true` (required when `preflight_require_supabase_health=true`)

Then dispatch GitHub Actions workflow `cycle-005-hosted-persistence-evidence` with:

- `local_runtime=false`
- `preflight_require_supabase_health=true`
- `preflight_only=false` (full evidence run)

# Prereqs

- GitHub CLI auth (already required by the scripts):
  - `gh auth status -h github.com`
- GitHub repo permissions:
  - You need `>= WRITE` on the target repo to set `HOSTED_WORKFLOW_BASE_URL` and dispatch workflows.
  - If you only have read access on `nicepkg/auto-company`, run against your fork (e.g. `junhengz/auto-company`) and later have a maintainer mirror the variable/workflow run on upstream.
- Fly auth (required to deploy):
  - Preferred: `export FLY_API_TOKEN="..."` (or `FLY_API_TOKEN` in your shell env)
  - Alternative: `flyctl auth login` (interactive)
- Supabase runtime env vars (required for `supabase-health` to pass):
  - `export NEXT_PUBLIC_SUPABASE_URL="https://<project-ref>.supabase.co"`
  - `export SUPABASE_SERVICE_ROLE_KEY="..."`
- Optional (only if you want CI to apply SQL bundle automatically):
  - GitHub secret `SUPABASE_DB_URL` populated in the target repo, and run with `skip_sql_apply=false`

# Deploy To Fly (Creates App + Volume + Secrets + Deploy)

This repo includes an operator script that:

- ensures Fly app exists (`auto-company-sq-autopilot`)
- ensures Fly volume `runs` exists (mounted at `/app/runs`)
- sets Fly secrets `NEXT_PUBLIC_SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`
- deploys via Fly remote builder
- probes `env-health`
- persists repo variable `HOSTED_WORKFLOW_BASE_URL=https://auto-company-sq-autopilot.fly.dev`
- dispatches a Cycle 005 preflight-only run (optional)

Command:

```bash
cd /home/zjohn/autocomp/auto-company

export FLY_API_TOKEN="..."  # required
export NEXT_PUBLIC_SUPABASE_URL="https://<project-ref>.supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="..."

# Use a repo you can write to (example: fork).
./scripts/devops/deploy-sq-autopilot-fly-and-preflight.sh \
  --app auto-company-sq-autopilot \
  --region iad \
  --repo junhengz/auto-company \
  --preflight-require-supabase-health true
```

If you want to deploy + set `HOSTED_WORKFLOW_BASE_URL` but skip the preflight dispatch:

```bash
./scripts/devops/deploy-sq-autopilot-fly-and-preflight.sh \
  --repo junhengz/auto-company \
  --skip-preflight
```

# Post-Deploy Probes (Local)

```bash
BASE_URL="https://auto-company-sq-autopilot.fly.dev"

curl -sS "$BASE_URL/api/workflow/env-health" | jq .
curl -sS "$BASE_URL/api/workflow/supabase-health" | jq .
```

Or use the bundled smoke checker (recommended before dispatching CI):

```bash
BASE_URL="https://auto-company-sq-autopilot.fly.dev"
REQUIRE_SUPABASE_HEALTH=1 \
  ./projects/security-questionnaire-autopilot/scripts/smoke-hosted-runtime.sh "$BASE_URL"
```

Expected:

- `env-health`: `.ok == true` and `.env.NEXT_PUBLIC_SUPABASE_URL == true` and `.env.SUPABASE_SERVICE_ROLE_KEY == true`
- `supabase-health`: `.ok == true`

# Dispatch Cycle 005 Evidence Run (Full)

The operator wrapper supports a full run via `--full` (sets `preflight_only=false`).

```bash
./scripts/devops/run-cycle-005-hosted-persistence-evidence.sh \
  --repo junhengz/auto-company \
  --full \
  --preflight-require-supabase-health true
```

Track the run:

```bash
gh run list -R junhengz/auto-company --workflow "cycle-005-hosted-persistence-evidence.yml" -L 5
```

# Common Blockers

- Fly deploy blocked:
  - Symptom: `flyctl auth whoami` fails
  - Fix: set `FLY_API_TOKEN` or run `flyctl auth login`

- `env-health` not `200` JSON:
  - Symptom: HTML response or non-200
  - Fix: wrong origin or deploy failed; re-deploy and probe `https://auto-company-sq-autopilot.fly.dev/api/workflow/env-health`

- `supabase-health` fails while `env-health` passes:
  - Fix: ensure Fly secrets are the real Supabase project URL + service role key, and that the SQL bundle has been applied to that same Supabase project
