# Cycle 018: Scripted GitHub Secrets + Workflow Dispatch + Artifact Fetch (Supabase CI)

Date: 2026-02-14  
Owner: operations-pg  
Objective: unblock CI Supabase provision+apply by making setup + dispatch + artifact capture fully scripted and evidence-producing.

## What You Get

One script that, using only a GitHub token + the `gh` CLI, can:

1. Verify required GitHub repo secrets exist:
   - `SUPABASE_ACCESS_TOKEN`
   - `SUPABASE_ORG_SLUG`
   - `SUPABASE_DB_PASSWORD`
2. Set any missing secrets (from env vars or interactive prompt; values never printed).
3. Dispatch `.github/workflows/cycle-005-supabase-provision-apply-verify.yml`.
4. Wait for completion and download run artifacts (including `supabase-verify.json`).
5. Write evidence + artifacts into `docs/operations-pg/` (this role’s mapped directory).

Script:
- `scripts/ops/cycle-018-supabase-ci.sh`

Default evidence directory:
- `docs/operations-pg/cycle-018-supabase-ci/run-<UTC_TS>/`

## Prereqs

1. Install dependencies:
   - `gh`
   - `jq`
2. Authenticate `gh` (recommended: PAT via env var):

```bash
export GH_TOKEN="***"  # PAT with repo + workflow permissions
gh auth status
```

## Inputs (Secrets) You Must Possess

You need the real values (store them in your secret manager; do not paste into docs):

- `SUPABASE_ACCESS_TOKEN`: Supabase Management API token (must be able to create/list projects in the org)
- `SUPABASE_ORG_SLUG`: Supabase org slug (string)
- `SUPABASE_DB_PASSWORD`: desired DB password for the provisioned project

## Copy/Paste: Run End-to-End (Recommended)

Non-interactive (values provided via env vars):

```bash
export SUPABASE_ACCESS_TOKEN="***"
export SUPABASE_ORG_SLUG="your-org-slug"
export SUPABASE_DB_PASSWORD="***"

./scripts/ops/cycle-018-supabase-ci.sh all
```

Interactive (prompts for missing values, no echo):

```bash
./scripts/ops/cycle-018-supabase-ci.sh all --prompt
```

## Copy/Paste: Just Verify Secrets Exist

```bash
./scripts/ops/cycle-018-supabase-ci.sh check-secrets
```

Exit codes:
- `0`: all required secrets present
- `3`: one or more required secrets missing (evidence still written)

## Copy/Paste: Set Secrets Only

```bash
export SUPABASE_ACCESS_TOKEN="***"
export SUPABASE_ORG_SLUG="your-org-slug"
export SUPABASE_DB_PASSWORD="***"

./scripts/ops/cycle-018-supabase-ci.sh set-secrets
```

Or prompt:

```bash
./scripts/ops/cycle-018-supabase-ci.sh set-secrets --prompt
```

## Copy/Paste: Dispatch With Custom Workflow Inputs

```bash
./scripts/ops/cycle-018-supabase-ci.sh dispatch \
  --supabase-project-name "security-questionnaire-autopilot-cycle-005" \
  --reuse-existing "true" \
  --sql-bundle "projects/security-questionnaire-autopilot/supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql"
```

## Where The Artifacts Land (Local)

After `all`, you should have:

- `docs/operations-pg/cycle-018-supabase-ci/run-*/supabase-verify.json` (convenience copy, if present)
- `docs/operations-pg/cycle-018-supabase-ci/run-*/artifacts/` (downloaded artifact contents)
- `docs/operations-pg/cycle-018-supabase-ci/run-*/run.view.json` + `run.api.json` (run metadata)

The workflow itself uploads (non-secret):
- `projects/security-questionnaire-autopilot/runs/supabase-provision-summary.json`
- `projects/security-questionnaire-autopilot/runs/supabase-provision.kv`
- `projects/security-questionnaire-autopilot/runs/supabase-connection-nonsecret.txt`
- `projects/security-questionnaire-autopilot/runs/supabase-verify.json`

## Troubleshooting (Common Failures)

- `gh auth status` fails:
  - Ensure `GH_TOKEN` is exported in your shell.
  - Ensure the token has permissions to read/write Actions secrets and run workflows.

- Secrets set fails with 403:
  - Token lacks permission to write Actions secrets for this repo.
  - If using a Fine-grained PAT: grant Repository permissions for Actions (Secrets: Read/Write) and Workflows (Read/Write) or equivalent.

- Dispatch succeeds but run not detected (timeout):
  - The script only auto-detects runs created after dispatch time on the selected `--ref`.
  - Manually find the run id:
    - `gh run list --workflow "cycle-005-supabase-provision-apply-verify.yml" --limit 10`
  - Then download explicitly:
    - `./scripts/ops/cycle-018-supabase-ci.sh download --run-id <ID>`

- Workflow not found / cannot be dispatched:
  - The workflow must exist on the branch/ref you dispatch (default: repo default branch).
  - Confirm it exists in the repo UI under Actions, or list via:
    - `gh workflow list`

- Workflow fails early with “Missing secret: …”:
  - Confirm secrets exist in the correct repo (not an org secret, not a fork).
  - Re-run: `./scripts/ops/cycle-018-supabase-ci.sh set-secrets --prompt`

- Supabase provisioning fails (HTTP 4xx/5xx):
  - `SUPABASE_ACCESS_TOKEN` invalid/expired or lacks create/list project permissions.
  - `SUPABASE_ORG_SLUG` incorrect.
  - Name collision + reuse disabled: set `--reuse-existing true` or pick a unique `--supabase-project-name`.

- Verify JSON exists but `.ok != true`:
  - The SQL bundle did not apply cleanly or the seed doesn’t match expected IDs.
  - Open the downloaded `supabase-verify.json` and use it as the authoritative failure report.

## Next Action

Run:

```bash
./scripts/ops/cycle-018-supabase-ci.sh all --prompt
```

Then open the newest `docs/operations-pg/cycle-018-supabase-ci/run-*/supabase-verify.json` and proceed based on `.ok`.
