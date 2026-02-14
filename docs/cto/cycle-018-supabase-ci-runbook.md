# Cycle 018 (CTO): Scripted Supabase CI Provision+Apply (Secrets + Dispatch + Artifacts)

Goal: an operator with only a GitHub token can:

1. Verify required repo secrets exist.
2. Set missing secrets (`SUPABASE_ACCESS_TOKEN`, `SUPABASE_ORG_SLUG`, `SUPABASE_DB_PASSWORD`) via `gh` or REST.
3. Dispatch `.github/workflows/cycle-005-supabase-provision-apply-verify.yml`.
4. Fetch run artifacts including `supabase-verify.json` into `docs/cto/`.
5. Troubleshoot common failures quickly.

All evidence for this flow lands under: `docs/cto/cycle-018-supabase-ci/`.

## Prereqs (Operator Machine)

- `gh` CLI installed
- `jq` installed
- A token exported as `GH_TOKEN` (or `GITHUB_TOKEN`)

Token permissions (fine-grained PAT):

- Repository: target repo selected
- Permissions:
  - Actions: Read and Write (dispatch workflows, download artifacts)
  - Secrets: Read and Write (list + set Actions secrets)
  - Contents: Read (workflow discovery)

## Quick Start (Recommended, Fully Scripted)

From this repo checkout:

```bash
export GH_TOKEN="github_pat_..."
REPO="nicepkg/auto-company"   # change if needed

# End-to-end: verify/set secrets (prompts), dispatch, watch, download artifacts into docs/cto/.
./scripts/devops/run-cycle-018-supabase-ci-cto.sh --repo "$REPO" --set-missing
```

Non-interactive (values from env; no prompts):

```bash
export GH_TOKEN="github_pat_..."
REPO="nicepkg/auto-company"

export SUPABASE_ACCESS_TOKEN="***"
export SUPABASE_ORG_SLUG="your-org-slug"
export SUPABASE_DB_PASSWORD="***"

./scripts/devops/run-cycle-018-supabase-ci-cto.sh --repo "$REPO" --set-missing --non-interactive
```

## Dispatch Options (When You Need Determinism)

Override workflow inputs explicitly:

```bash
export GH_TOKEN="github_pat_..."
REPO="nicepkg/auto-company"

./scripts/devops/run-cycle-018-supabase-ci-cto.sh --repo "$REPO" --set-missing \
  --supabase-project-name "security-questionnaire-autopilot-cycle-005" \
  --reuse-existing true \
  --sql-bundle "projects/security-questionnaire-autopilot/supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql"
```

Dispatch a non-default ref:

```bash
./scripts/devops/run-cycle-018-supabase-ci-cto.sh --repo "$REPO" --set-missing --ref "main"
```

## Evidence Outputs (What To Look At)

These files are written (non-secret):

- Secret presence check:
  - `docs/cto/cycle-018-supabase-ci/gh-secrets-check-*.json`
- Secret set attempts:
  - `docs/cto/cycle-018-supabase-ci/gh-secrets-set-*.json`
- Dispatch run metadata:
  - `docs/cto/cycle-018-supabase-ci/dispatch-*.json`
- Artifact download and extracted signals:
  - `docs/cto/cycle-018-supabase-ci/runs/<run_dbid>-<ts>/download-evidence.json`
  - `docs/cto/cycle-018-supabase-ci/runs/<run_dbid>-<ts>/supabase-verify.json` (if present)
  - `docs/cto/cycle-018-supabase-ci/runs/<run_dbid>-<ts>/project_ref.txt` (if parsed)

The authoritative success signal is:

- `supabase-verify.json` has `.ok == true`

## Setting Secrets Via REST (Alternative to `gh secret set`)

When you cannot (or prefer not to) use `gh secret set`, use:

- `scripts/devops/github-actions-secret-set-rest.py`

It requires `PyNaCl`:

```bash
python3 -m pip install --user pynacl
```

Example (stdin; avoids shell history):

```bash
export GH_TOKEN="github_pat_..."

printf '%s' "your-supabase-access-token" | python3 scripts/devops/github-actions-secret-set-rest.py \
  --repo "nicepkg/auto-company" \
  --name "SUPABASE_ACCESS_TOKEN" \
  --value-stdin
```

Repeat for:

- `SUPABASE_ORG_SLUG`
- `SUPABASE_DB_PASSWORD`

## Common Failures (Fast Triage)

### 1) `check-secrets` fails with 403 / cannot list secrets

Cause: token lacks permission to read Actions secrets metadata.

Fix:

1. Re-issue token with `Secrets: Read and Write` permission for the repo.
2. Re-run `check-secrets`.

### 2) `dispatch` fails with HTTP 404

Cause: workflow file not present on the target repo/ref.

Fix:

- Confirm workflow exists:
  - `gh workflow list -R "$REPO"`
- If it exists only on a branch, re-run with `--ref <branch>`.

### 3) `dispatch` fails with HTTP 422 mentioning `workflow_dispatch`

Cause: workflow exists but is not dispatchable on that ref (no `workflow_dispatch` on that branch).

Fix:

- Dispatch the ref that contains `workflow_dispatch`, or merge it to the default branch.

### 4) Workflow run fails early: “Missing secret: SUPABASE_*”

Cause: required secret not configured (or empty).

Fix:

- Run `./scripts/devops/run-cycle-018-supabase-ci-cto.sh --repo "$REPO" --set-missing`

### 5) Supabase provisioning fails (HTTP non-200/201) inside the workflow

Common causes:

- Invalid/expired `SUPABASE_ACCESS_TOKEN`
- Wrong `SUPABASE_ORG_SLUG`
- Org policy blocks project creation by token
- Region selection invalid (if `SUPABASE_REGION_SELECTION_JSON` is set)

Fix:

- Download artifacts and inspect `provision.json` and `provision.kv` from:
  - `docs/cto/cycle-018-supabase-ci/runs/<run_dbid>-<ts>/artifacts/`

### 6) Apply step succeeds but verify fails (`supabase-verify.json` missing or `.ok != true`)

Cause: bundle did not apply as expected or seed/schema mismatch.

Fix:

- Download artifacts and inspect `supabase-verify.json`:
  - `docs/cto/cycle-018-supabase-ci/runs/<run_dbid>-<ts>/supabase-verify.json`
- Compare expected bundle id and seed indicators.

## Next Action

Run:

```bash
export GH_TOKEN="github_pat_..."
REPO="nicepkg/auto-company"
./scripts/devops/run-cycle-018-supabase-ci-cto.sh --repo "$REPO" --set-missing
```
