# Cycle 003 (QA-Bach): Hosted Baseline For SQ Autopilot (2026-02-14)

## Objective
1. Identify the canonical GitHub repo that owns Actions secrets/variables for SQ Autopilot hosted checks.
2. Set repo variable `HOSTED_WORKFLOW_BASE_URL` to a stable hosted runtime origin (non-tunnel).
3. Dispatch `.github/workflows/sq-autopilot-hosted-integration.yml` once to establish a green hosted baseline.

## Canonical Repo (Secrets/Variables Owner)

### Code canonical vs Actions-config canonical
- **Code canonical (upstream):** `nicepkg/auto-company` (not a fork).
- **Actions-config canonical (operational, writable):** `junhengz/auto-company` (fork) because the current operator token has admin/push rights there but **not** on `nicepkg/auto-company`.

Evidence (operator can reproduce):

```bash
# Upstream vs fork relationship
gh repo view nicepkg/auto-company --json nameWithOwner,isFork,parent,defaultBranchRef
gh repo view junhengz/auto-company --json nameWithOwner,isFork,parent,defaultBranchRef

# Permission surface (this is what decides if you can set vars/secrets)
gh api /repos/junhengz/auto-company | jq '.permissions'
gh api /repos/nicepkg/auto-company | jq '.permissions'

# Variables/secrets access: expect 403 on upstream if you are not a collaborator
gh variable list -R nicepkg/auto-company
gh secret list -R nicepkg/auto-company
```

Decision for Cycle #3 execution:
- Run Cycle #3 against `junhengz/auto-company` unless/until `nicepkg/auto-company` grants variables/secrets permissions.

## Step 1: Verify You Have A Real Hosted Runtime Origin

The hosted integration workflow requires a **single origin** (no path) that serves:
- `GET /api/workflow/env-health` as JSON
- with `.ok==true`
- and (by default) both env booleans true:
  - `.env.NEXT_PUBLIC_SUPABASE_URL==true`
  - `.env.SUPABASE_SERVICE_ROLE_KEY==true`

Fast check:

```bash
BASE_URL="https://<stable-runtime-origin>"
./docs/qa-bach/cycle-029-hosted-workflow-origin-curl-commands-2026-02-14.sh
```

Hard rule:
- Do **not** use ephemeral tunnel domains (`*.trycloudflare.com`, `*.loca.lt`, `*.lhr.life`, etc).

## Step 2: Set `HOSTED_WORKFLOW_BASE_URL` (Repo Variable)

Target repo:

```bash
REPO="junhengz/auto-company"
BASE_URL="https://<stable-runtime-origin>"

gh variable set HOSTED_WORKFLOW_BASE_URL -R "$REPO" --body "$BASE_URL"
gh variable list -R "$REPO" | rg '^HOSTED_WORKFLOW_BASE_URL\\b'
```

Note:
- As of 2026-02-14, `junhengz/auto-company` may contain a placeholder value (e.g. a Fly domain) that is not yet resolvable; do not trust it without the curl check above.

## Step 3: Dispatch Hosted Integration Workflow Once

Pre-check: ensure workflow exists on the target repo/ref:

```bash
REPO="junhengz/auto-company"
gh workflow list -R "$REPO" | rg 'sq-autopilot-hosted-integration' || true
```

Manual dispatch (uses repo variable if `base_url` omitted):

```bash
REPO="junhengz/auto-company"
REF="main"

gh workflow run sq-autopilot-hosted-integration.yml -R "$REPO" --ref "$REF"
gh run list -R "$REPO" --workflow sq-autopilot-hosted-integration.yml --limit 3
```

If you want to override once (without relying on the repo variable):

```bash
REPO="junhengz/auto-company"
REF="main"
BASE_URL="https://<stable-runtime-origin>"

gh workflow run sq-autopilot-hosted-integration.yml -R "$REPO" --ref "$REF" \\
  -f base_url="$BASE_URL" \\
  -f require_supabase_env=true \\
  -f require_supabase_health=false
```

Watch the run:

```bash
REPO="junhengz/auto-company"
RUN_ID="$(gh run list -R "$REPO" --workflow sq-autopilot-hosted-integration.yml --limit 1 --json databaseId --jq '.[0].databaseId')"
gh run watch -R "$REPO" "$RUN_ID" --exit-status
```

## Current Blocker Snapshot (2026-02-14)
- No stable public hosted workflow runtime origin is currently verifiable from this environment:
  - Fly target `https://auto-company-sq-autopilot.fly.dev` is `NXDOMAIN` here.
  - Vercel candidates observed in prior probes return `DEPLOYMENT_NOT_FOUND`.
  - `https://auto-company.pages.dev` returns HTML (marketing/static), not JSON.

That means Cycle #3 cannot produce a green hosted baseline until a real deployment exists.

## Next Action
Provision a stable hosted runtime origin for `projects/security-questionnaire-autopilot` (non-tunnel), verify it passes `GET /api/workflow/env-health`, then set `HOSTED_WORKFLOW_BASE_URL` on `junhengz/auto-company` and dispatch `sq-autopilot-hosted-integration.yml` once.

