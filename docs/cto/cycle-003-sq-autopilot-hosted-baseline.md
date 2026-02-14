# Cycle 003: SQ Autopilot Hosted Baseline (Canonical Repo + BASE_URL)

## Constraints / Facts (2026-02-14)

- Canonical repo for Actions variables/secrets (operationally): `junhengz/auto-company`
  - We have `ADMIN` permissions here (can set repo variables).
  - Upstream `nicepkg/auto-company` is `READ` only; GitHub API returns `403` for repo Actions variables.
- Canonical hosted runtime origin contract: repo variable `HOSTED_WORKFLOW_BASE_URL` (single origin; no tunnels; no paths).
- Target stable origin (Fly convention): `https://auto-company-sq-autopilot.fly.dev`
  - Note: as of 2026-02-14 this hostname is `NXDOMAIN` until the Fly app is created and deployed.

## 1) Identify Canonical Repo Ownership

```bash
gh repo view nicepkg/auto-company --json nameWithOwner,viewerPermission,defaultBranchRef
gh repo view junhengz/auto-company --json nameWithOwner,viewerPermission,defaultBranchRef

# Actions variables access (expected: nicepkg 403, junhengz ok)
gh variable list -R nicepkg/auto-company || true
gh variable list -R junhengz/auto-company
```

Decision: treat `junhengz/auto-company` as the canonical repo that owns Actions variables/secrets for SQ Autopilot automation.

## 2) Set `HOSTED_WORKFLOW_BASE_URL` (Single Stable Origin)

```bash
gh variable set HOSTED_WORKFLOW_BASE_URL \
  -R "junhengz/auto-company" \
  --body "https://auto-company-sq-autopilot.fly.dev"

gh api /repos/junhengz/auto-company/actions/variables/HOSTED_WORKFLOW_BASE_URL | jq .
```

## 3) Ensure The Hosted Runtime Exists (Fly)

The hosted integration workflow is intentionally strict: it expects the selected `BASE_URL` to serve:

- `GET <BASE_URL>/api/workflow/env-health` -> `200` JSON with `.ok == true`

Bootstrap deployment path:

1. Install `flyctl`:

```bash
curl -L https://fly.io/install.sh | sh
export PATH="$HOME/.fly/bin:$PATH"
flyctl version
```

2. Provide Fly auth (non-interactive):

```bash
export FLY_API_TOKEN="..."   # required
```

3. Deploy the runtime and persist `HOSTED_WORKFLOW_BASE_URL`:

```bash
scripts/devops/deploy-sq-autopilot-fly-and-preflight.sh \
  --repo "junhengz/auto-company" \
  --preflight-require-supabase-health false
```

This deploy script:
- Creates the Fly app + volume (if missing)
- Deploys `projects/security-questionnaire-autopilot`
- Verifies `/api/workflow/env-health`
- Writes repo variable `HOSTED_WORKFLOW_BASE_URL`

## 4) Dispatch Hosted Integration Workflow Once (Green Baseline)

Once the Fly deployment is live, dispatch:

```bash
# Direct gh command:
gh workflow run sq-autopilot-hosted-integration.yml \
  -R "junhengz/auto-company" \
  --ref "main" \
  -f "require_supabase_env=true" \
  -f "require_supabase_health=false"

# Or wrapper:
scripts/devops/run-sq-autopilot-hosted-integration.sh \
  --repo "junhengz/auto-company" \
  --wait
```

Observe the run:

```bash
gh run list -R "junhengz/auto-company" --workflow "sq-autopilot-hosted-integration.yml" -L 3
```

## Failure Modes (Expected, Actionable)

- `NXDOMAIN` / DNS failure on `*.fly.dev`: Fly app not created/deployed yet.
  - Fix: deploy via `scripts/devops/deploy-sq-autopilot-fly-and-preflight.sh` with a valid `FLY_API_TOKEN`.
- `env-health` returns HTML: wrong domain (marketing/static Pages site), not the Next.js workflow runtime.
  - Fix: point `HOSTED_WORKFLOW_BASE_URL` at the deployed workflow runtime origin.

