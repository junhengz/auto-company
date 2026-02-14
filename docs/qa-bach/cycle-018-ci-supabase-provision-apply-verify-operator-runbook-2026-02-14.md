# Cycle 018: Scripted Secrets + Workflow Dispatch (Supabase Provision + Apply + Verify)

Date: 2026-02-14
Owner: qa-bach

## Objective (Operator-Executable)

With only a GitHub token (plus the Supabase secret values you intend to store), an operator can:

1. Verify required repo secrets exist.
2. Set missing secrets (`SUPABASE_ACCESS_TOKEN`, `SUPABASE_ORG_SLUG`, `SUPABASE_DB_PASSWORD`) via `gh`.
3. Dispatch `.github/workflows/cycle-005-supabase-provision-apply-verify-dispatch.yml`.
4. Fetch artifacts including `supabase-verify.json`.
5. Troubleshoot common failure modes using evidence logs + machine-checkable JSON.

All evidence lands under `docs/qa-bach/`.

## Preconditions

- `gh` installed and authenticated.
- `jq` installed.
- GitHub repo permission `WRITE` (or higher) to set secrets and dispatch workflows.

Authenticate (non-interactive example):

```bash
export GH_TOKEN="github_pat_..."
gh auth status -h github.com
```

## Step 1: Verify / Set Repo Secrets (Scripted + Evidence)

Required secrets (names only):
- `SUPABASE_ACCESS_TOKEN`
- `SUPABASE_ORG_SLUG`
- `SUPABASE_DB_PASSWORD`

Check presence (no mutation):

```bash
scripts/devops/gh-ensure-supabase-provision-secrets.sh --repo OWNER/REPO
```

Set missing secrets from env (no prompts, no secret printing):

```bash
export SUPABASE_ACCESS_TOKEN="..."
export SUPABASE_ORG_SLUG="my-org-slug"
export SUPABASE_DB_PASSWORD="..."

scripts/devops/gh-ensure-supabase-provision-secrets.sh \
  --repo OWNER/REPO \
  --set-missing \
  --non-interactive
```

If you omit `--non-interactive`, the script will prompt for missing values on a TTY (token/password are masked).

Evidence output (auto-created):
- `docs/qa-bach/cycle-018-gh-secrets-supabase-provision-*.json`
- `docs/qa-bach/cycle-018-gh-secrets-supabase-provision-*.log`

## One-Shot (Secrets + Dispatch + Artifact Download)

If you want a single command that runs Step 1 and Step 2:

```bash
scripts/devops/run-cycle-018-supabase-provision-apply-verify-one-shot.sh --repo OWNER/REPO --set-missing
```

## Step 2: Dispatch Provision + Apply + Verify Workflow (Scripted)

Dispatch + watch + download artifacts:

```bash
scripts/devops/gh-dispatch-cycle-005-supabase-provision-apply-verify.sh --repo OWNER/REPO
```

Common overrides:

```bash
scripts/devops/gh-dispatch-cycle-005-supabase-provision-apply-verify.sh \
  --repo OWNER/REPO \
  --supabase-project-name "security-questionnaire-autopilot-cycle-005" \
  --reuse-existing true \
  --sql-bundle "projects/security-questionnaire-autopilot/supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql"
```

Evidence output directory:
- `docs/qa-bach/cycle-018-supabase-provision-apply-verify-run-<ts>/`
- Includes `dispatch.json`, `dispatch.log`, `watch.log`, and downloaded artifacts under `artifact/`.

## Step 3: Confirm Machine-Checkable Result

Primary signal:
- `docs/qa-bach/cycle-018-supabase-provision-apply-verify-run-*/supabase-verify.json`

Check the result:

```bash
jq -e '.ok == true' docs/qa-bach/cycle-018-supabase-provision-apply-verify-run-*/supabase-verify.json
```

## Troubleshooting (Fast Triage)

### HTTP 403 when checking secrets

Symptoms:
- Evidence JSON shows status `forbidden` for secrets.

Likely cause:
- Token lacks required permissions, or you only have `READ` on the repo.

Fix:
- Use a token/user with repo permission `WRITE`+ (or set secrets via GitHub UI).

### Dispatch fails (workflow not found / not dispatchable)

Symptoms:
- `dispatch.log` includes `HTTP 404` or `HTTP 422` mentioning `workflow_dispatch`.

Likely causes:
- Workflow file is not on the repo default branch.
- Workflow lacks `on: workflow_dispatch` on that branch/ref.

Fix:
- Retry with `--ref <branch>` that contains the workflow.
- Or merge the workflow into the default branch, then retry.

### Run fails early: “Missing secret: SUPABASE_*”

Symptoms:
- Run logs show missing secret checks in the “Provision Supabase project” step.

Fix:
- Re-run Step 1 with `--set-missing`, then re-dispatch.

### Supabase API create fails (HTTP 4xx/5xx)

Symptoms:
- Run logs show `Supabase project create failed (HTTP ...)`.

Likely causes:
- Supabase token lacks org permissions.
- Org requires `SUPABASE_REGION_SELECTION_JSON` (optional secret) and it is not set.
- Duplicate project naming conflict when `reuse_existing=false`.

Fix:
- Ensure token/org slug are correct.
- If required, set `SUPABASE_REGION_SELECTION_JSON` as a GitHub secret (org-specific).
- Prefer `--reuse-existing true`.

### Artifact missing `supabase-verify.json`

Symptoms:
- Script prints: “Artifact did not include supabase-verify.json”.

Likely causes:
- Run failed before the SQL apply/verify step executed.
- Artifact upload step didn’t run or uploaded nothing.

Fix:
- Inspect `watch.log`, and the run URL in `dispatch.json`.
- Re-run after fixing missing secrets or workflow errors.

## Notes on REST API (Why `gh secret set` is used)

GitHub’s Actions Secrets REST API requires client-side encryption using the repo’s public key before you can store a secret value. `gh secret set` performs that encryption locally and then stores the secret via the REST API, without printing the value.

## Next Action

Run:

1. `scripts/devops/gh-ensure-supabase-provision-secrets.sh --repo OWNER/REPO --set-missing`
2. `scripts/devops/run-cycle-005-supabase-provision-apply-verify.sh --repo OWNER/REPO`
