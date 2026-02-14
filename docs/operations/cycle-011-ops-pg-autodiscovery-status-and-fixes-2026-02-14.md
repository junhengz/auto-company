# Cycle 011 (Operations/PG): Autodiscovery Status + Fixes (2026-02-14)

## 1) Do We Have the PR #3 Autodiscovery Improvements Locally?
Mostly yes. The repo contains provider-backed candidate collection scripts and a deterministic selector that probes `/api/workflow/env-health`.

### Vercel: production + preview + aliases
Implemented in:
- `projects/security-questionnaire-autopilot/scripts/collect-base-url-candidates-from-vercel-api.sh`

What it does:
- pulls project domains
- lists deployments for `target=production` and `target=preview`
- adds `deployment.url` and inline `aliases`
- best-effort calls `GET /v2/deployments/{id}/aliases` for a limited set of deployments to capture branch/preview aliases

### Cloudflare Pages: recent deployments + aliases
Implemented in:
- `projects/security-questionnaire-autopilot/scripts/collect-base-url-candidates-from-cloudflare-pages-api.sh`

What it does:
- pulls `result.subdomain` and project domains
- pulls domains endpoint
- lists recent deployments for `env=production` and `env=preview`
- extracts URL fields plus alias field variants (`aliases`, `deployment_aliases`, `deploymentAliases`)

### Wiring: selector uses hosting APIs before GitHub Deployments (when creds exist)
Implemented in:
- `projects/security-questionnaire-autopilot/scripts/select-hosted-base-url.sh`

## 2) Fix Applied: Workflow Discovery Precedence
Problem:
- `.github/workflows/cycle-005-hosted-persistence-evidence.yml` claimed to mirror selector precedence, but attempted **GitHub Deployments discovery before hosting APIs**.

Fix applied (local):
- prefer `collect-base-url-candidates-from-hosting.sh` first, then GitHub Deployments fallback.

File:
- `.github/workflows/cycle-005-hosted-persistence-evidence.yml`

## 3) Canonical Repo Reality Check
If `nicepkg/auto-company` is the canonical repo, it currently has **no workflows** (Actions Workflows API shows 0).

Operational implication:
- even perfect autodiscovery code won’t run until the workflow files are present on the default branch of the canonical repo.

## 4) Exact Patch Summary (What Changed)
- Cloudflare Pages candidates: capture alias field variants from deployments list.
  - `projects/security-questionnaire-autopilot/scripts/collect-base-url-candidates-from-cloudflare-pages-api.sh`
- Workflow discovery precedence: provider-first, then GitHub Deployments.
  - `.github/workflows/cycle-005-hosted-persistence-evidence.yml`

