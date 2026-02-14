# Cycle 011: Fixes/Patches Needed (and Applied in This Workspace)

Date: 2026-02-14

## 1) Autodiscovery Improvements (PR #3 Scope)
Already present on this workspace branch (`cycle-008-hosting-discovery-v2`):
- Cloudflare Pages: recent deployments + aliases (production+preview) in `projects/security-questionnaire-autopilot/scripts/collect-base-url-candidates-from-cloudflare-pages-api.sh`.
- Vercel: production+preview + deployment alias enrichment in `projects/security-questionnaire-autopilot/scripts/collect-base-url-candidates-from-vercel-api.sh`.

On upstream `origin` (`nicepkg/auto-company`), these are not usable operationally because the repo currently has **no workflows** (0 under `actions/workflows`), so there is nothing to dispatch for Cycle 005 evidence.

## 2) Provider-First Candidate Assembly (Workflow)
Change applied:
- `.github/workflows/cycle-005-hosted-persistence-evidence.yml`

What changed:
- When there are no explicit candidates/vars, the workflow now assembles candidates as:
  - hosting APIs first (Vercel/Cloudflare if configured)
  - plus GitHub Deployments metadata as a supplemental source

Why:
- Provider APIs are fresher and include deployment aliases; Deployments metadata is frequently empty/stale.

## 3) Wrapper Autodiscovery Ordering + Whitespace Bug Fix
Changes applied:
- `scripts/devops/run-cycle-005-hosted-persistence-evidence.sh`

What changed:
- When `--autodiscover` is used, the wrapper now prefers hosting discovery first, then GitHub Deployments, and merges/dedupes.
- Fixed a whitespace-only formatting edge case that could throw `No candidates found in file: /tmp/...`.
- Improved the error message when the target repo does not contain the workflow (HTTP 404), so operators get the correct remediation (`gh workflow list -R <repo>` and run against the repo/ref that actually contains the workflow).

## 4) Cloudflare Pages Candidate Collector: Preview URL Fields
Change applied:
- `projects/security-questionnaire-autopilot/scripts/collect-base-url-candidates-from-cloudflare-pages-api.sh`

What changed:
- Added best-effort capture of `preview_url` / `previewUrl` from deployments, in addition to aliases and `deployment_url`/`url`.

## 5) Upstream Merge/Sync Requirement
To run Cycle 005 evidence against `nicepkg/auto-company`, the upstream repo must contain (at minimum):
- `.github/workflows/cycle-005-hosted-persistence-evidence.yml`
- `.github/workflows/cycle-005-hosted-runtime-env-sync.yml`
- `projects/security-questionnaire-autopilot/scripts/*` (candidate collectors, selection/probe scripts, env-sync scripts)
- `scripts/devops/run-cycle-005-hosted-persistence-evidence.sh` (optional but recommended operator path)

Without those, preflight cannot be dispatched (404 / no workflows).

