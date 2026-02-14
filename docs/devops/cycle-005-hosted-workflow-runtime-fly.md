# Cycle 005 Hosted Workflow Runtime (Fly.io)

Goal: provide a stable public origin for `projects/security-questionnaire-autopilot` that serves
`/api/workflow/*` and preserves `runs/<runId>/*` across sequential calls.

This repo's workflow runtime shells out to Python:

- Node API routes call `python3 -m sq_autopilot.cli ...`
- Run state is written to local disk under `projects/security-questionnaire-autopilot/runs/`

Serverless hosts (Cloudflare Pages/Workers, Vercel Node functions) do not reliably provide:

- a `python3` binary for `execFile("python3", ...)`
- persistent local disk between requests

Fly.io (single machine + volume mount) is the lowest-ops fit for the current runtime shape.

## What We Deploy

- App: Next.js app in `projects/security-questionnaire-autopilot`
- Docker build: `projects/security-questionnaire-autopilot/Dockerfile`
- Fly config: `projects/security-questionnaire-autopilot/fly.toml`
- Persistence: Fly Volume mounted at `/app/runs` (maps to repo-relative `runs/`)

## One-Time Setup (Operator)

Prereqs on the operator machine:

- `gh` logged in with `repo` + `workflow` scopes
- `flyctl` installed (`curl -L https://fly.io/install.sh | sh`)
- Fly auth: `flyctl auth login` (browser), or `flyctl auth login --email ... --password ... --otp ...`

## Provision + Deploy

From repo root:

```bash
export PATH="$HOME/.fly/bin:$PATH"
cd projects/security-questionnaire-autopilot

# Authenticate to Fly
flyctl auth login

# Optional: use the one-shot helper (deploy + set variable + dispatch preflight)
./scripts/devops/deploy-sq-autopilot-fly-and-preflight.sh

# Create the app (name must be globally unique)
flyctl apps create auto-company-sq-autopilot

# Create a small volume for run artifacts (same region as fly.toml primary_region)
flyctl volumes create runs --app auto-company-sq-autopilot --region iad --size 1

# Set required env vars on the hosted runtime (env-health must show true booleans).
# Use real Supabase values when available. Non-empty placeholders are acceptable for
# Cycle 005 preflight-only (supabase-health can be disabled).
flyctl secrets set \
  NEXT_PUBLIC_SUPABASE_URL="https://example.supabase.co" \
  SUPABASE_SERVICE_ROLE_KEY="service_role_placeholder" \
  --app auto-company-sq-autopilot

# Deploy
flyctl deploy --app auto-company-sq-autopilot
```

Expected origin:

- `BASE_URL=https://auto-company-sq-autopilot.fly.dev`

Validate:

```bash
curl -sS "https://auto-company-sq-autopilot.fly.dev/api/workflow/env-health" | jq .
```

## Wire Into Cycle 005

Persist the deployed origin into the repo variable:

```bash
gh variable set HOSTED_WORKFLOW_BASE_URL_CANDIDATES -R junhengz/auto-company --body \
  "https://auto-company-sq-autopilot.fly.dev"
```

Then run Cycle 005 preflight-only without local runtime:

```bash
scripts/devops/run-cycle-005-hosted-persistence-evidence.sh \
  --repo junhengz/auto-company \
  --preflight-only \
  --preflight-require-supabase-health false
```

## Rollback / Recovery

- Fast rollback: `flyctl releases --app auto-company-sq-autopilot` then `flyctl deploy --app ... --image <previous>`
- Volume safety:
  - `runs/` artifacts live on the Fly volume (`source=runs`, `destination=/app/runs`).
  - Do not scale to multiple machines while using a single attached volume.

## Risks / Notes

- This config pins a single machine (`min_machines_running=1`) to preserve sequential-call disk state.
- If we later need horizontal scaling, migrate run artifacts from local disk to a shared store (R2/S3/Supabase Storage)
  and remove the volume constraint.
