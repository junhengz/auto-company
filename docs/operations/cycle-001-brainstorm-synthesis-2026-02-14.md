# Cycle 001 Brainstorm Synthesis (2026-02-14)

Inputs:
- `docs/ceo/cycle-001-brainstorm-2026-02-14.md`
- `docs/cto/cycle-001-brainstorm-2026-02-14.md`
- `docs/product/cycle-001-brainstorm-2026-02-14.md`
- `docs/research/cycle-001-brainstorm-2026-02-14.md`
- `docs/cfo/cycle-001-brainstorm-2026-02-14.md`

## Theme Convergence
Four of five roles converge on the same root cause and fix:
- Root cause: hosted runtime instability + “candidate URL discovery” creates entropy and CI flakiness.
- Fix: one canonical, stable base URL (custom domain) with an explicit health contract; remove discovery/guessing from CI; add guardrails to prevent tunnel origins from being persisted.

The outlier (CTO) is aligned on the product direction but shifts focus to MVP feature scope and GTM rather than the immediate hosting/CI blocker.

## Top 3 Ideas (Ranked)
### 1) Canonical Hosted Workflow Base URL + CI Decoupling
Source: CEO + Research (and broadly compatible with CFO).
- Ship one stable hosted endpoint (custom domain) with health/ready/version contract.
- Replace “candidate scanning” with a single source of truth (`HOSTED_WORKFLOW_BASE_URL`-style contract).
- Move hosted integration checks into a separate lane (nightly/manual) so PR gating remains deterministic.

Why #1: directly unblocks customer trust and eliminates the current CI failure mode with the shortest path to “boringly reliable”.

### 2) Local-First Workflow Runtime Kit (CI + Pilots)
Source: Product.
- Make local runtime the default (compose + one-command runner + smoke test).
- CI preflight talks to `127.0.0.1` by default; customer pilots can run the same kit inside their network.

Why #2: highest leverage for deterministic CI; pairs well with #1 by removing network dependence from the default dev/PR loop.

### 3) Minimal Hosted “CI Contract” Endpoint + Monitoring (Staging/Prod)
Source: CFO.
- Keep the hosted surface area tiny at first: `/health`, `/version`, and a minimal “no-op” workflow endpoint used by preflight.
- Add synthetic monitoring to detect downtime before CI/customers do.

Why #3: keeps scope and cost down while creating a credible hosted story; provider choice should match runtime constraints (Python + persistence).

## Single Most Important Next Step
Stop allowing tunnel origins to poison hosted-base-url selection:
- Add validation/filtering for candidate URLs (tunnel domain ban).
- Promote a single canonical base URL path for hosted checks (no discovery-by-default).

