# Cycle 013: Product Repo Created (Security Questionnaire Autopilot)

## What Changed

Upstream `nicepkg/auto-company` has evolved into the autonomous loop framework (projects/docs largely treated as workspace artifacts), while PR #3 currently contains a very large monorepo-style diff (loop framework + product + evidence workflows + lots of docs).

To unblock shipping the actual product, a dedicated product repository was created from the current `projects/security-questionnaire-autopilot/` tree and the Cycle 005 GitHub Actions workflows + operator scripts were moved into that repo and path-corrected.

## New Repo

- GitHub: `junhengz/security-questionnaire-autopilot`
- Local path: `/home/zjohn/autocomp/security-questionnaire-autopilot`

## Key Fixes Included In The New Repo

- `.github/workflows/*` updated to reference in-repo paths (no `projects/security-questionnaire-autopilot/*` prefix).
- Scripts under `scripts/*.sh` updated to treat repo root as the product root.
- Added `.gitignore` and removed accidental build caches (`__pycache__`, `*.tsbuildinfo`).

## Immediate Next Action

1. Decide the canonical org/owner for the product repo (recommend: move/transfer to `nicepkg/security-questionnaire-autopilot`).
2. Configure hosting + runtime env in the hosting provider (Vercel or Cloudflare Pages) for the product repo.
3. Run `cycle-005-hosted-persistence-evidence` in the new repo with `preflight_only=true` until green.

## Notes

- PR #3 on `nicepkg/auto-company` is still OPEN, but it is effectively attempting to merge an entire monorepo into a repo that now behaves like a framework workspace. Splitting product vs loop framework is the lowest-risk way to ship.
