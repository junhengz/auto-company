# Cycle 001 Brainstorm (2026-02-14): One 2-Week Direction

## Scope + Source Set
- Scope: pick one concrete next direction for the next ~2 weeks that maximizes shipping + revenue impact by unblocking stable hosting and CI reliability for the workflow API used by Security Questionnaire Autopilot.
- Source set (repo-local): `CLAUDE.md` (role mapping), and the stated blocker: `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` gets poisoned by ephemeral tunnel origins causing CI preflight failures.

## Idea (Exactly One)
**Ship a single, stable “Production Workflow Base URL” (custom domain) plus a base-URL governance rule that removes candidate scanning from CI.**

In practice: stop treating hosted workflow origins as a discoverable list (which invites entropy); instead treat the hosted runtime as an operational product with one canonical URL and an explicit allowlist/update mechanism owned by the maintainer.

## What We Ship (Concrete)
1. **One canonical URL** for the hosted workflow API (custom domain) used by CI and by customer-facing ops runs (for example: `https://workflow.<your-domain>`).
2. **CI policy change**: replace “probe candidates and select one” with “use exactly `HOSTED_WORKFLOW_BASE_URL` (single value) and fail fast if unhealthy”.
3. **Governance mechanism**: base URL changes only via a deliberate, auditable path (example: a dedicated PR/template or a small script that writes a single file like `docs/devops/base-url-candidate.txt` or equivalent), with a hard rule: **no tunnel URLs** (ngrok/cloudflared/etc.) land in versioned config.
4. **Runtime health contract**: one endpoint the pipeline can rely on (example: `GET /api/workflow/env-health` or similar) returning deterministic OK/FAIL so failures are attributable to runtime health, not discovery heuristics.

## Why This Maximizes Shipping + Revenue (Ben Thompson Frame)
- **Value chain clarity**: the “workflow gate engine + evidence-backed ops” is only as sellable as its reliability. A flaky base URL pushes you back into bespoke consulting; a stable base URL turns the system into a repeatable production capability.
- **Aggregation thinking**: security questionnaires are a repeated demand pattern; the compounding advantage is operational throughput (more questionnaires/week with fewer failures). Reliability improvements compound directly into capacity to onboard more customers at the same headcount.
- **Distribution economics**: if your delivery mechanism (hosted runtime + CI evidence generation) is stable, you can credibly promise turnaround SLAs and price accordingly (onboarding fee + monthly + overages).

## How We Validate (Within 2 Weeks)
- **CI reliability metric**: 0 CI preflight failures attributable to base URL selection across at least 10 consecutive runs.
- **Customer delivery metric**: run at least one end-to-end hosted execution that produces the expected evidence artifacts (run/event persistence proof) without manual base-URL intervention.
- **Operational metric**: time-to-run (from “need evidence” to “evidence landed”) becomes predictable (target: minutes, not hours of chasing origins).

## Execution Plan (5-10 Bullets)
- Pick the hosting target already closest to “always-on” in your stack; attach a custom domain and confirm the URL will not change across redeploys.
- Define and document the single canonical env var (`HOSTED_WORKFLOW_BASE_URL`) and delete/ignore the candidate list in CI codepaths.
- Add a hard “no tunnels in versioned config” rule (grep-based gate in CI is fine) to prevent future poisoning.
- Implement or standardize one health endpoint contract and wire CI preflight to it.
- Create a single-file source of truth for the base URL (owned by maintainer) and a minimal process for changing it (PR + checklist).
- Run 10 consecutive CI validations; if any fail, categorize: DNS, TLS, app boot, secrets/env, network, provider incident.
- Perform one real hosted run for customer delivery/evidence generation and confirm the artifacts land in the expected docs/evidence locations.
- Write a short operator note: “If health fails, do X; if deploy changes, verify Y” so the next incident is shorter.

## What Could Go Wrong
- **Provider instability or misconfiguration** (DNS/TLS/region outages) makes the single canonical URL a single point of failure.
- **Secrets/env drift** between “what CI expects” and “what runtime has” can still break runs (but failure becomes attributable and repeatable).
- **Over-rotation on purity**: if you need a tunnel for emergency debugging, you might slow incident response; mitigate by allowing tunnels locally but banning them from committed config.

## Confidence
- `likely`: This will materially reduce CI entropy and unlock consistent evidence-generation runs, because the root problem is “discovery + poisoning,” not lack of features.
- `speculative`: The exact hosting/provider choice may still be contentious; the strategic move is the governance shift to *one canonical URL* and *no discovery* in CI.

## Unknowns / Next Data to Collect
- Which hosting provider is currently “closest to stable” for the workflow API (where it is actually deployed today), and whether it supports a truly static origin behind a custom domain.
- Where `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` is set/updated today (script, workflow step, docs), and the minimal change needed to remove discovery from CI.

## Next Action
Identify the current deployed hosted workflow runtime and its provider, then define the canonical custom-domain base URL and remove candidate scanning from CI in the next PR.

