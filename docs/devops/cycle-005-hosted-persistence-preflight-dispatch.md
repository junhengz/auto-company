# Cycle 005 Hosted Persistence: Preflight-Only Dispatch (Ops Runbook)

This runbook documents how to dispatch the `cycle-005-hosted-persistence-evidence.yml` GitHub Actions workflow in **preflight-only** mode via the operator wrapper script:

`scripts/devops/run-cycle-005-hosted-persistence-evidence.sh`

Preflight-only validates:
- Candidate `BASE_URL` selection
- `GET <BASE_URL>/api/workflow/env-health`
- `GET <BASE_URL>/api/workflow/supabase-health?...` (only when `skip_sql_apply=true`)

It intentionally performs **no evidence capture** and **creates no PR**.

## One Command (Requested Dispatch)

Exact command (as run from this repo workspace):

```bash
./scripts/devops/run-cycle-005-hosted-persistence-evidence.sh \
  --repo junhengz/auto-company \
  --autodiscover-github \
  --preflight-only \
  --skip-sql-apply true
```

### Result (Observed 2026-02-14)

This dispatch attempt **did not reach GitHub Actions** because no `BASE_URL` candidates were available and GitHub Deployments autodiscovery returned none:

- Failure: `Missing BASE_URL candidates.`
- Fix: provide candidates via repo variable or `--base-url` (see below).

## Requirements

### Local Dependencies

- `gh` (GitHub CLI) authenticated
- Optional for local probing/smoke: `curl`, `jq`

The wrapper performs local probing by default; use `--no-local-probe` if your workstation cannot reach the deployed runtime (VPN/DNS/egress restrictions).

### GitHub Permissions

To dispatch and watch runs on `junhengz/auto-company`:

- GitHub CLI auth scopes: `repo`, `workflow`
- Repo permissions: ability to trigger workflows (typically write access)

If you want the wrapper to set repo variables directly (e.g., `--set-variable`, `--autorun true|false`):

- Permission to manage GitHub Actions Variables on the target repo

If you cannot manage repo variables but can dispatch workflows, prefer:

- `--persist-candidates` (workflow persists `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` using `GITHUB_TOKEN`)

## BASE_URL Candidates (Most Common Blocker)

The workflow runner needs 2-4 deployed **Next.js runtime origins** that serve:

- `GET /api/workflow/env-health`

Candidates must be absolute origins like:
- `https://<project>.vercel.app`
- `https://<project>.pages.dev`
- `https://<custom-domain>`

### Option A: Set Repo Variable (Recommended)

```bash
gh variable set HOSTED_WORKFLOW_BASE_URL_CANDIDATES \
  -R "junhengz/auto-company" \
  --body "https://candidate-1.example https://candidate-2.example"
```

Then re-run the requested command.

### Option B: Pass Candidates Without Persisting

```bash
./scripts/devops/run-cycle-005-hosted-persistence-evidence.sh \
  --repo junhengz/auto-company \
  --base-url "https://candidate-1.example https://candidate-2.example" \
  --preflight-only \
  --skip-sql-apply true
```

### Option C: Persist From the Workflow (When You Cannot Edit Repo Variables)

```bash
./scripts/devops/run-cycle-005-hosted-persistence-evidence.sh \
  --repo junhengz/auto-company \
  --base-url "https://candidate-1.example https://candidate-2.example" \
  --persist-candidates \
  --preflight-only \
  --skip-sql-apply true
```

### Option D: File-Based Candidates (Template)

Edit `docs/devops/base-url-candidates.template.txt` and then:

```bash
./scripts/devops/run-cycle-005-hosted-persistence-evidence.sh \
  --repo junhengz/auto-company \
  --candidates-file docs/devops/base-url-candidates.template.txt \
  --set-variable \
  --preflight-only \
  --skip-sql-apply true
```

## Autodiscovery

### GitHub Deployments (What `--autodiscover-github` Uses)

`--autodiscover-github` attempts to read GitHub Deployments metadata via `gh api` and extract `environment_url` / `target_url`.

It will return nothing if the repo does not publish Deployments metadata for the hosting platform, or if permissions do not allow reading deployments.

### Hosting Provider APIs (Optional)

If you want best-effort discovery from hosting providers, use `--autodiscover-hosting` or `--autodiscover` (both).

Vercel discovery inputs:
- `VERCEL_TOKEN` (secret)
- `VERCEL_PROJECT_ID` or `VERCEL_PROJECT` (vars)
- optional: `VERCEL_TEAM_ID` or `VERCEL_TEAM_SLUG`

Cloudflare Pages discovery inputs:
- `CLOUDFLARE_API_TOKEN` (secret)
- `CF_PAGES_PROJECT` (var)
- `CLOUDFLARE_ACCOUNT_ID` or `CLOUDFLARE_ACCOUNT_NAME` (var)

## Hosted Runtime Env Vars (Second Most Common Blocker)

The preflight checks the deployed runtime (not GitHub Actions secrets) for:
- `NEXT_PUBLIC_SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

Verify quickly:

```bash
curl -sS "https://<BASE_URL>/api/workflow/env-health" | jq .
```

If these are missing, set them in the hosting provider environment variables (Vercel/Cloudflare Pages) and redeploy.

## Safe Reruns

### Rerun Without Local Probing (Let GHA Probe)

Use this when local network access to the deployed host is unreliable:

```bash
./scripts/devops/run-cycle-005-hosted-persistence-evidence.sh \
  --repo junhengz/auto-company \
  --base-url "https://candidate-1.example https://candidate-2.example" \
  --preflight-only \
  --skip-sql-apply true \
  --no-local-probe
```

### Rerun With Explicit Ref (Workflow Not on Default Branch)

```bash
./scripts/devops/run-cycle-005-hosted-persistence-evidence.sh \
  --repo junhengz/auto-company \
  --ref <branch-or-sha> \
  --base-url "https://candidate-1.example https://candidate-2.example" \
  --preflight-only \
  --skip-sql-apply true
```

## Where Artifacts Land

The wrapper prints:
- `GHA run databaseId: <id>`
- `GHA run url: <url>` (when available)

In GitHub Actions for workflow `cycle-005-hosted-persistence-evidence.yml`, look for these artifacts:

- `cycle-005-hosted-base-url-probe`
  - `preflight/base-url-candidates.txt`
  - `preflight/base-url-source.txt`
  - `preflight/base-url-probe.txt`

- `cycle-005-hosted-preflight`
  - `preflight/env-health.json`
  - `preflight/env-health.after-redeploy.json` (if an env-sync attempt happened)
  - `preflight/supabase-health.json`
  - plus selector logs like `preflight/select-base-url.err`

Download artifacts via CLI:

```bash
gh run download -R "junhengz/auto-company" <RUN_DBID> -n cycle-005-hosted-preflight -D /tmp/cycle-005-preflight
```

## Common Failure Modes (And What They Usually Mean)

- Missing BASE_URL candidates
  - No repo variable set and autodiscovery yielded none
  - Fix: set `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` or pass `--base-url`

- HTTP 403 when reading repo variables/secrets
  - Your token can dispatch but cannot read repo Actions vars/secrets
  - Fix: pass `--base-url` explicitly, or use `--persist-candidates`

- HTTP 403 when setting repo variables
  - Lacking Actions Variables write permission
  - Fix: use `--persist-candidates`, or ask a repo admin to set variables

- HTTP 404 from `gh workflow run ...cycle-005-hosted-persistence-evidence.yml`
  - Workflow file not present on the target repo default branch/ref
  - Fix: `gh workflow list -R junhengz/auto-company`, or re-run with `--ref ...`

- HTTP 422 from `gh workflow run` mentioning `workflow_dispatch`
  - Workflow exists but is not dispatchable from the target ref
  - Fix: run with `--ref <branch>` that contains `workflow_dispatch`, or merge it to default branch

- 404/5xx when probing `GET <BASE_URL>/api/workflow/env-health`
  - Candidate is not the workflow runtime, or deployment is unhealthy
  - Fix: update candidates to the correct deployed app origin and redeploy if needed

- env-health shows missing Supabase env vars
  - Hosted runtime not configured (Vercel/Pages env vars not set for Production)
  - Fix: set hosting env vars, redeploy, then rerun preflight

## Next Action

Set `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` for `junhengz/auto-company` (or rerun with `--base-url ...`), then rerun the preflight dispatch (optionally with `--no-local-probe`).

