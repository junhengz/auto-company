# Cycle 021: Set `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` (junhengz/auto-company) (2026-02-14)

## Goal

Make Cycle 005 hosted preflight deterministic by setting a canonical list of production workflow-runtime origins in the repo variable:

- `HOSTED_WORKFLOW_BASE_URL_CANDIDATES`

## Requirements For Each Candidate

Each candidate must be an origin (no path) such that:

```bash
curl -sS "<BASE_URL>/api/workflow/env-health" | jq -e \
  '.ok==true and .env.NEXT_PUBLIC_SUPABASE_URL==true and .env.SUPABASE_SERVICE_ROLE_KEY==true'
```

If it returns HTML, `404`, or `DEPLOYMENT_NOT_FOUND`, it is the wrong domain (marketing/static, stale preview, or no deployment).

## Command (GitHub Repo Variable)

```bash
gh variable set HOSTED_WORKFLOW_BASE_URL_CANDIDATES -R "junhengz/auto-company" --body \
"https://<origin-1> https://<origin-2> https://<origin-3>"
```

## Self-Healing Option (Preferred)

If you can only provide candidates once (e.g., from provider UI), you can persist them from a single manual dispatch:

```bash
gh workflow run cycle-005-hosted-persistence-evidence.yml -R "junhengz/auto-company" \
  -f preflight_only=true \
  -f skip_sql_apply=true \
  -f preflight_require_supabase_health=true \
  -f persist_base_url_candidates=true \
  -f base_url="https://<origin-1> https://<origin-2>"
```

This persists a formatted de-duplicated list into `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` using the workflow `GITHUB_TOKEN`.

