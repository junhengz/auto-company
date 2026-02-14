# Cycle 011: Runtime Discovery + Preflight Fixes (DevOps-Hightower)

This is a changelog of the concrete fixes needed to make hosted runtime discovery and Cycle 005 preflight runnable.

## 1) Canonical Repo Missing The Workflow + Discovery Scripts

Status as of 2026-02-14:

- `nicepkg/auto-company` `main` does **not** have the Cycle 005 hosted persistence evidence workflow file.
- Therefore, `gh workflow run cycle-005-hosted-persistence-evidence.yml -R nicepkg/auto-company ...` returns 404.

Fix:

- Open PR into `nicepkg/auto-company:main` from `junhengz:cycle-008-hosting-discovery-v2`.
- Merge it.

## 2) Workflow Dispatch Was Broken (GitHub Expression Rules)

Problem:

- GitHub Actions does not allow `secrets.*` in `if:` expressions.
- The workflow contained step `if:` conditions referencing `secrets.VERCEL_TOKEN` and `secrets.CLOUDFLARE_API_TOKEN`, making `workflow_dispatch` invalid.

Fix (merged into fork branch `cycle-008-hosting-discovery-v2`):

- Remove `secrets.*` checks from `if:`.
- Gate inside the step script instead (skip with a message when tokens/ids are missing).

File:

- `.github/workflows/cycle-005-hosted-persistence-evidence.yml`

## 3) Provider-First Discovery Ordering (Better Default)

Problem:

- GitHub Deployments metadata is often empty; provider APIs are typically more authoritative.

Fix:

- Prefer hosting provider API discovery before GitHub Deployments discovery, both in:
  - `.github/workflows/cycle-005-hosted-persistence-evidence.yml`
  - `scripts/devops/run-cycle-005-hosted-persistence-evidence.sh` (`--autodiscover` path)

## 4) Cloudflare Pages Deployments Alias Shape Drift

Problem:

- Cloudflare Pages deployments JSON alias fields can drift; `.aliases` is not always the only field.

Fix:

- `projects/security-questionnaire-autopilot/scripts/collect-base-url-candidates-from-cloudflare-pages-api.sh`
  now extracts aliases from multiple likely field names:
  - `aliases`
  - `deployment_aliases`
  - `deploymentAliases`

