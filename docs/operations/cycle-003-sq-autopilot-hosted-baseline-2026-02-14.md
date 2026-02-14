# Cycle 003: Hosted Baseline For SQ Autopilot (2026-02-14)

## Goal

1. Identify the canonical GitHub repo that owns GitHub Actions secrets/variables for this codebase.
2. Set repo variable `HOSTED_WORKFLOW_BASE_URL` to a stable hosted workflow runtime origin (non-tunnel).
3. Dispatch `.github/workflows/sq-autopilot-hosted-integration.yml` once to establish a green hosted baseline.

## Canonical Repo (Secrets/Variables Owner)

Canonical repo is the upstream `origin` remote:

- `nicepkg/auto-company`

Reason: scheduled/manual workflows run on the repo that contains the workflow files; our local checkout tracks `origin/main`.

Operational note: as of 2026-02-14, the current `gh` identity (`junhengz`) has `READ` on `nicepkg/auto-company` and cannot set variables or dispatch workflows there. A maintainer with `WRITE+` on `nicepkg/auto-company` must run the commands below.

## Stable BASE_URL Contract

`HOSTED_WORKFLOW_BASE_URL` must be a single origin (no path) that serves:

- `GET <BASE_URL>/api/workflow/env-health` => HTTP 200 JSON with `.ok == true`

For strict “real hosted” runs, `env-health` must also report:

- `.env.NEXT_PUBLIC_SUPABASE_URL == true`
- `.env.SUPABASE_SERVICE_ROLE_KEY == true`

Quick probe:

```bash
BASE_URL="https://<your-runtime-origin>"
curl -fsS -m 12 "${BASE_URL%/}/api/workflow/env-health" | jq -e \
  '.ok == true and .env.NEXT_PUBLIC_SUPABASE_URL == true and .env.SUPABASE_SERVICE_ROLE_KEY == true'
```

## Commands (Maintainer With WRITE+)

### 1) Set the repo variable

```bash
REPO="nicepkg/auto-company"
BASE_URL="https://<your-runtime-origin>"

gh variable set HOSTED_WORKFLOW_BASE_URL -R "$REPO" --body "$BASE_URL"
```

### 2) Dispatch hosted integration once (variable-driven)

This leaves `base_url` empty so the workflow reads `vars.HOSTED_WORKFLOW_BASE_URL`.

```bash
REPO="nicepkg/auto-company"

gh workflow run sq-autopilot-hosted-integration.yml -R "$REPO" --ref main \
  -f base_url="" \
  -f require_supabase_env=true \
  -f require_supabase_health=false
```

Optional: watch the run

```bash
REPO="nicepkg/auto-company"
gh run list -R "$REPO" -w sq-autopilot-hosted-integration -L 3
gh run watch -R "$REPO" <run_id> --exit-status
```

### 3) Optional wrapper script (same actions)

```bash
./scripts/devops/run-sq-autopilot-hosted-integration.sh \
  --repo nicepkg/auto-company \
  --base-url "https://<your-runtime-origin>" \
  --set-variable \
  --watch
```

## Current Blocker Snapshot (2026-02-14)

- No confirmed publicly reachable hosted workflow runtime origin exists yet for this repo (prior candidates were marketing/static, NXDOMAIN, or Vercel `DEPLOYMENT_NOT_FOUND`).
- Fork `junhengz/auto-company` currently has `HOSTED_WORKFLOW_BASE_URL=https://auto-company-sq-autopilot.fly.dev`, but DNS is `NXDOMAIN` (not deployed).

## Next Action

Pick the real production hosted runtime origin from the hosting provider UI (Vercel recommended), confirm it passes `/api/workflow/env-health` JSON probe, then a `nicepkg/auto-company` maintainer runs:

1. `gh variable set HOSTED_WORKFLOW_BASE_URL -R nicepkg/auto-company --body "<origin>"`
2. `gh workflow run sq-autopilot-hosted-integration.yml -R nicepkg/auto-company --ref main -f base_url=""`

