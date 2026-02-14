# Cycle 011: Hosted Persistence Evidence Preflight Report (2026-02-14)

## Objective

Run the Cycle 005 hosted persistence evidence workflow in **preflight-only** mode (`preflight_only=true`) and capture what is blocking.

## Attempt A: Canonical Repo (`nicepkg/auto-company`)

Command:

```bash
gh workflow run cycle-005-hosted-persistence-evidence.yml -R nicepkg/auto-company -f preflight_only=true -f skip_sql_apply=true
```

Result:

- Blocked: workflow file is missing on `nicepkg/auto-company` default branch.
- Error:
  - `HTTP 404: Not Found (https://api.github.com/repos/nicepkg/auto-company/actions/workflows/cycle-005-hosted-persistence-evidence.yml)`

Conclusion:

- Preflight cannot be executed in the canonical repo until the workflow is merged into `nicepkg/auto-company:main`.

## Attempt B: Fork Repo (`junhengz/auto-company`) Using Branch `cycle-008-hosting-discovery-v2`

Command:

```bash
gh workflow run cycle-005-hosted-persistence-evidence.yml -R junhengz/auto-company \
  --ref cycle-008-hosting-discovery-v2 \
  -f preflight_only=true \
  -f skip_sql_apply=true
```

Run:

- `https://github.com/junhengz/auto-company/actions/runs/22008589305`

Failure:

- Step: `Assemble + probe deployed BASE_URL candidates (always)`
- Reason: no candidates available from any source, so the workflow fails fast with exit code 2.

Evidence from logs:

- Repo variables were empty:
  - `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` empty
  - legacy candidate vars empty
- Provider creds were empty:
  - `VERCEL_TOKEN` empty
  - `CLOUDFLARE_API_TOKEN` empty
  - plus required IDs (`VERCEL_PROJECT_ID`/`VERCEL_PROJECT`, `CLOUDFLARE_ACCOUNT_ID`, `CF_PAGES_PROJECT`) empty
- GitHub Deployments discovery returned no URLs.

Conclusion:

- Blocking input is **authoritative BASE_URL candidates** (preferred) OR **provider credentials/ids** to auto-discover them.

