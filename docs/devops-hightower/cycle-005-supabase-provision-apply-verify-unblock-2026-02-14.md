# Cycle 005: Supabase Provision + Apply + Verify (Unblock, 2026-02-14)

## Current Status (as of 2026-02-14)

Target repo: `junhengz/auto-company` (viewerPermission: `ADMIN`)

Blocking issue: required GitHub Actions secrets are missing:

- `SUPABASE_ACCESS_TOKEN`
- `SUPABASE_ORG_SLUG`
- `SUPABASE_DB_PASSWORD`

Machine-checkable evidence (current state, expected to be `ok=false` until secrets are set):

- Secret presence check:
  - `docs/devops/evidence/actions-secrets-check-junhengz_auto-company-20260214T033157Z-402190-21478.json`
- Workflow dispatch + extracted fallback verification:
  - `docs/devops/evidence/workflow-dispatch-20260214T033352Z.json`
  - `docs/devops/evidence/supabase-verify-run-22010383272.json`

`docs/devops/evidence/supabase-verify-run-22010383272.json` shows:

- `.ok=false`
- `.missing_secrets=["SUPABASE_ACCESS_TOKEN","SUPABASE_ORG_SLUG","SUPABASE_DB_PASSWORD"]`
- `.reason="workflow_failed_before_apply"`

## Unblock Steps (to reach `.ok == true`)

### 0) Gather the 3 values (takes ~2-4 minutes)

You need three values to store as GitHub Actions repo secrets (these are not committed to git):

1. `SUPABASE_ACCESS_TOKEN` (Supabase Personal Access Token)
   - Supabase Dashboard: Account/Settings -> Access Tokens -> create token.
   - Minimum requirement: token can create/manage projects in the target org (Mgmt API access).
2. `SUPABASE_ORG_SLUG`
   - Supabase Dashboard: open your org; the URL includes the slug (commonly `.../org/<org-slug>`).
3. `SUPABASE_DB_PASSWORD`
   - Choose a strong password you can keep stable for this provisioned project.
   - If you want a quick generator:

```bash
openssl rand -base64 24
```

### 1) Set the 3 required GitHub Actions secrets in `junhengz/auto-company`

Interactive (prompts via `/dev/tty`, does not echo values):

```bash
scripts/devops/gh-ensure-supabase-provision-secrets.sh \
  --repo junhengz/auto-company \
  --set-missing
```

Non-interactive (source values from env vars; safe for automation):

```bash
export SUPABASE_ACCESS_TOKEN="..."
export SUPABASE_ORG_SLUG="..."
export SUPABASE_DB_PASSWORD="..."

scripts/devops/gh-ensure-supabase-provision-secrets.sh \
  --repo junhengz/auto-company \
  --set-missing \
  --non-interactive
```

Optional (if you want to control region selection via the Mgmt API):

- Add repo secret `SUPABASE_REGION_SELECTION_JSON` (example value: `{"type":"smartGroup","code":"americas"}`).

### 2) Run the end-to-end workflow and capture evidence

```bash
scripts/devops/run-cycle-005-supabase-provision-apply-verify.sh \
  --repo junhengz/auto-company \
  --supabase-project-name "security-questionnaire-autopilot-cycle-005" \
  --reuse-existing true
```

This wrapper downloads artifacts and extracts the non-secret verification JSON into:

- `docs/devops/evidence/supabase-verify-run-<RUN_ID>.json`

### 3) Machine-check: assert success

```bash
jq -e '.ok == true' "docs/devops/evidence/supabase-verify-run-<RUN_ID>.json" >/dev/null
```

## Risk / Rollback

Risk:
- The Supabase PAT (`SUPABASE_ACCESS_TOKEN`) is powerful. Treat it like a root credential.

Rollback:
- If you suspect a leak: revoke the Supabase PAT in Supabase Dashboard, rotate the project DB password, then update the three GitHub secrets.
- To remove secrets from GitHub: repo Settings -> Secrets and variables -> Actions, or via `gh secret remove NAME -R junhengz/auto-company`.

## Minimal Script Changes Applied (to reduce confusion / avoid blocking)

- `scripts/devops/gha-workflow-dispatch.sh`
  - Now fails fast (and writes JSON evidence) if repo permission is < `WRITE`.
  - Now writes JSON evidence if `gh workflow run ...` fails.
- `scripts/devops/gha-secrets-set.sh`
  - Prompts only via `/dev/tty` and fails fast if no TTY (prevents hanging reads in automation).
- `scripts/devops/run-cycle-005-supabase-provision-apply-verify.sh`
  - Makes `--repo` inference explicit early and uses a consistent `--repo` for all sub-steps.
