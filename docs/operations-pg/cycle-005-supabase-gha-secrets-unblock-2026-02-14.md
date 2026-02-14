# Cycle 005: Unblock Supabase GHA Secrets (junhengz/auto-company)

## Deterministic Fallback (No Secrets)

If provisioning secrets are unavailable, you can still produce Cycle 005 evidence immediately:

```bash
./scripts/cycle-005/run-no-secrets-evidence.sh --repo junhengz/auto-company
```

Runbook: `docs/operations-pg/cycle-005-no-secrets-fallback-2026-02-14.md`

## Current Status (Evidence)

As of `2026-02-14T03:51:55Z`, the repo `junhengz/auto-company` has **none** of the required GitHub Actions secrets configured:

- `SUPABASE_ACCESS_TOKEN`
- `SUPABASE_ORG_SLUG`
- `SUPABASE_DB_PASSWORD`

Evidence JSON:

- `docs/devops/evidence/actions-secrets-check-junhengz_auto-company-20260214T035154Z-410476-6906.json`

Workflow fallback artifact (proves the pipeline can dispatch and upload artifacts even while blocked):

- Run ID: `22010670298`
- `docs/devops/evidence/supabase-verify-run-22010670298.json` (shows `ok=false` and `missing_secrets=[...]`)

## Stage (Ops Diagnosis)

Pre-PMF infrastructure unblock: shipping the provisioning workflow matters more than debating the perfect secret ownership model. The constraint is simply: no one has populated the required repo secrets yet.

## Top Priorities (This Cycle)

1. Set the 3 required secrets in `junhengz/auto-company` so `cycle-005-supabase-provision-apply-verify-dispatch.yml` can run.
2. Immediately re-run the workflow and capture artifacts/evidence under `docs/devops/evidence/`.

## Weekly Goal (Measurable)

- By end of day `2026-02-14` UTC: `scripts/devops/gha-secrets-verify.sh --repo junhengz/auto-company` returns success (no missing secrets), and a successful workflow run ID is recorded with artifacts downloaded.

## Common Trap

Spending time trying to automate secret generation. The fastest path is a single maintainer doing a 2-minute credential gather + 1 command to set secrets, then re-running the workflow.

## 5-Minute Runbook (Human Operator)

### 1) Verify what’s missing (names only)

```bash
./scripts/devops/gha-secrets-verify.sh --repo junhengz/auto-company
```

Expected right now: it reports all 3 secrets missing and writes evidence under `docs/devops/evidence/`.

### 2) Gather values (Supabase)

- `SUPABASE_ACCESS_TOKEN`: Supabase personal access token with org/project management capability.
- `SUPABASE_ORG_SLUG`: the org slug string (from Supabase org URL/settings).
- `SUPABASE_DB_PASSWORD`: desired Postgres password for the provisioned project (set/reset as needed).

### 3) Set secrets via script (prompts, no echo for secrets)

Interactive (fastest, avoids value printing):

```bash
./scripts/devops/gha-secrets-set.sh \
  --repo junhengz/auto-company \
  --required "SUPABASE_ACCESS_TOKEN SUPABASE_ORG_SLUG SUPABASE_DB_PASSWORD"
```

Non-interactive (CI/operator shell with env vars already present):

```bash
export SUPABASE_ACCESS_TOKEN="..."
export SUPABASE_ORG_SLUG="..."
export SUPABASE_DB_PASSWORD="..."

./scripts/devops/gha-secrets-set.sh \
  --repo junhengz/auto-company \
  --required "SUPABASE_ACCESS_TOKEN SUPABASE_ORG_SLUG SUPABASE_DB_PASSWORD" \
  --non-interactive
```

### 4) Verify secrets are now present

```bash
./scripts/devops/gha-secrets-verify.sh --repo junhengz/auto-company
```

### 5) Dispatch Cycle 005 provision/apply/verify and download artifacts

```bash
./scripts/devops/run-cycle-005-supabase-provision-apply-verify.sh \
  --repo junhengz/auto-company
```

If you want the wrapper to prompt and set missing secrets during the run:

```bash
./scripts/devops/run-cycle-005-supabase-provision-apply-verify.sh \
  --repo junhengz/auto-company \
  --set-missing-secrets
```
