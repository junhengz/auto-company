# Cycle 001 Brainstorm (2026-02-14): Stable Hosted Workflow + CI Decoupling

## Customer And Core Problem
**Customer:** Security, IT, and procurement teams (and the sales engineers supporting them) who need security questionnaires completed quickly with auditable evidence.

**Core problem:** We cannot reliably deliver “questionnaire autopilot” value while our workflow API runtime is not stable and public. Internally, CI is failing because `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` gets poisoned by ephemeral tunnel URLs, creating false negatives and slowing shipping. Externally, any customer-facing pilot that depends on a hosted workflow endpoint inherits that instability and erodes trust.

## One Idea (Two-Week Bet)
**Ship a single canonical, stable hosted Workflow API endpoint (custom domain) and make CI treat hosted integration as a separate, non-blocking lane.**

This is not “build more features.” It is making the workflow runtime *boringly reliable* so the rest of the product can compound.

### What We Ship (Concrete)
1. **Canonical hosted endpoint**: `https://workflow.<our-domain>/` (custom domain, TLS) backed by a real deployment target (no tunnels), with:
   - `GET /healthz` (fast, no dependencies)
   - `GET /readyz` (checks required deps)
   - `GET /version` (git SHA/build id)
2. **Anti-poisoning guardrails**:
   - Remove or stop reading `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` in CI preflight.
   - Replace with a single `HOSTED_WORKFLOW_BASE_URL` (one value) and enforce allowlist: must be `https://` and match our domain.
3. **CI reliability change**:
   - Default CI runs against a local runtime (docker/dev server).
   - Hosted integration tests move to a scheduled (nightly) job and/or a manual “integration” workflow; failures alert but do not block PR merges.

## How We Validate (In 2 Weeks)
- **Engineering metric:** PR preflight success rate returns to “boring” (target: > 98% green on first run over 7 days, excluding real test failures).
- **Operational metric:** hosted endpoint uptime and latency are visible (basic checks + logs), with an on-call-style alert for hard downtime.
- **Customer metric:** run at least 1 pilot flow end-to-end that hits the canonical endpoint and produces an evidence-backed completion artifact without “try again later” moments.

## Strategic Judgment / Priority
This is a **two-way door** operationally (we can move hosts later), but it unlocks **one-way door** customer perception: reliability. Without it, we’ll burn cycles fighting CI and we’ll be forced into bespoke customer hand-holding that does not scale.

## Key Risks / What Could Go Wrong
- The chosen hosting target can’t support a needed runtime behavior (long-running jobs, webhooks, auth callbacks) without redesign.
- We accidentally create “split brain” between local and hosted behavior; customers see different results than CI.
- We underinvest in observability and discover outages only when CI or a customer breaks.
- Security risk: exposing a public endpoint without tight auth/rate limiting.

## Execution Plan (5-10 Bullets)
- Pick the hosting target that supports our runtime needs with the least ops burden, and commit to it for 2 weeks (custom domain from day 1).
- Implement `healthz/readyz/version` endpoints and ensure they are part of the deploy acceptance gate.
- Add strict validation for `HOSTED_WORKFLOW_BASE_URL` (scheme + domain allowlist); delete/ignore `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` everywhere CI touches.
- Update CI preflight to run local workflow runtime by default; pin ports/config; eliminate external network dependency for PR gating.
- Create a separate “Hosted Integration” workflow (scheduled nightly + manual dispatch) that tests the canonical endpoint and reports failures to a single owner channel.
- Add minimal observability: request logs, error rate, and uptime checks for `/healthz` and `/readyz`.
- Lock down access: auth required for non-health endpoints; basic rate limiting; ensure secrets/config are not logged.
- Run one customer-like pilot script against the canonical endpoint and capture evidence artifacts; treat any flakiness as a P0.

