# Cycle 001 Brainstorm (2026-02-14): One Idea

## Financial Conclusion
Ship a **stable hosted Workflow API “Staging” endpoint** (single provider, single canonical URL) and make **CI preflight hit only that endpoint**. This removes revenue-killing CI flakiness immediately and creates a credible “hosted” story for paid pilots within ~2 weeks.

## The One Idea
**Cloudflare-Workers-hosted Workflow API v0 (staging + prod) with a canonical domain + CI contract endpoints**.

What we ship:
- A publicly reachable, stable base URL (example: `https://workflow-staging.<our-domain>`).
- Minimal but explicit “CI contract” endpoints: `GET /health`, `GET /version`, and one no-op workflow endpoint used by preflight.
- GitHub Actions deploy on merge to `main` (staging auto; prod manual approval).
- Repo config change: stop using `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` in CI preflight; use exactly one stable `HOSTED_WORKFLOW_BASE_URL` (staging) in CI.

Why this is the best next 2 weeks (CFO lens):
- **Stops churn of engineering time** spent re-running/re-fixing CI caused by tunnels.
- **Enables paid pilot confidence**: “Yes, we host it” without overbuilding multi-tenant infra.
- Keeps variable costs near-zero until revenue exists.

## Key Numbers (Estimates)
- Engineering time: 3-5 days to stand up worker + domain + CI change; 2-4 days hardening + pilot onboarding support.
- Infra cost: Cloudflare Workers early-stage typically ~$0-$5/mo unless traffic is meaningful (treat as de minimis vs dev time).
- Success metric: CI preflight reliability to **99.9%+** over 100+ runs; hosted endpoint uptime **99%+** during pilot window.

## How We Validate (in 14 days)
- CI: run preflight on every PR and on a nightly schedule; track failure rate and root cause.
- Runtime: synthetic ping from 2 regions every 1-5 minutes; alert on >2 consecutive failures.
- GTM: onboard 1 design partner using the hosted endpoint; measure “time-to-first-successful-workflow run” (target: <60 minutes).

## What Could Go Wrong (and Mitigations)
- Risk: Workers limitations (long-lived connections, cold starts, missing runtime features).
  - Mitigation: keep v0 surface area tiny; implement only endpoints needed for CI + pilot; push heavy workflow execution behind a queue later.
- Risk: “Hosted” scope creep (auth, multi-tenancy, persistence) delays the goal.
  - Mitigation: define a hard CI contract; anything beyond CI endpoints is behind a feature flag and not required for cycle success.
- Risk: Domain/DNS/provisioning friction slows day 1.
  - Mitigation: start with Cloudflare-managed subdomain; defer vanity domain polish until after CI is green.

## Execution Plan (5-10 bullets)
- Define the CI contract: exact endpoints + expected responses (status codes, JSON fields).
- Pick one hosting target (Cloudflare Workers) and provision `workflow-staging` + `workflow-prod`.
- Implement `GET /health` + `GET /version` + preflight no-op endpoint; return deterministic JSON.
- Add deploy pipeline: auto-deploy staging on merge; prod requires manual approval.
- Update CI to use only `HOSTED_WORKFLOW_BASE_URL` (staging) and remove/ignore `HOSTED_WORKFLOW_BASE_URL_CANDIDATES`.
- Add synthetic monitoring + alerting (even a minimal cron + webhook is fine).
- Run a “CI burn-in”: 100+ preflight invocations across PRs/nightly; confirm reliability.
- Run 1 paid pilot (or paid proof-of-concept) using the hosted endpoint; document onboarding steps and friction.

