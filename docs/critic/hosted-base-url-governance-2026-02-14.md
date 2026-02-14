# Hosted BASE_URL Governance (Security Questionnaire Autopilot CI) (2026-02-14)

## Verdict: support (with guardrails)

Single-source-of-truth for the hosted workflow runtime origin is the correct move. Candidate lists are a predictable “poison the well” mechanism (ephemeral tunnels, preview URLs) and eventually become a chronic PR/CI unblock tax.

## Key Risks / Potential Fatal Flaws

- **Silent “works on my machine” drift**: if devs rely on multi-candidate discovery locally, then CI becomes stricter and surprises them. Mitigation: keep a manual probe tool (`discover-hosted-base-url.sh`) but make CI workflows reject multi-candidate inputs.
- **Misconfigured repo variable blocks everything**: if `HOSTED_WORKFLOW_BASE_URL` is unset or set to a marketing domain, scheduled/manual hosted checks go red. Mitigation: fail fast with a concrete fix command; keep hosted checks out of PR gating.
- **Legacy variable confusion**: teams will keep setting `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` out of habit. Mitigation: CI paths ignore legacy vars and warn when present.
- **Incentive bias**: people will try to “get green” by stuffing multiple candidates, hoping one passes. Mitigation: enforce exactly one origin in the resolver.

## Concrete Failure Scenarios (Pre-mortem)

1. **Tunnel URL poisoning**: someone runs a quick tunnel, then persists it into a repo variable; future CI fails until a human repairs it.
   - Prevention implemented: CI/workflows only accept one origin via `HOSTED_WORKFLOW_BASE_URL` and reject tunnel domains via `validate-base-url-candidates.sh`.
2. **Multi-candidate roulette**: CI selects “the first passing” candidate; the selected one changes run-to-run and intermittently fails.
   - Prevention implemented: resolver enforces exactly one normalized origin (no scanning/selection).
3. **Hosted checks accidentally gate PRs**: hosted runtime is flaky for unrelated reasons and blocks merges.
   - Prevention implemented: hosted integration checks remain in scheduled/manual workflows (not `pull_request`).

## Deliverables Implemented

- Canonical single-origin resolver script:
  - `projects/security-questionnaire-autopilot/scripts/resolve-hosted-workflow-base-url.sh`
- PR-gating safety: removed legacy `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` scanning from the base-url selection wrapper:
  - `projects/security-questionnaire-autopilot/scripts/select-hosted-base-url.sh`
- Hosted integration workflow now resolves and validates the canonical origin (no candidate scanning) and uploads resolver artifacts:
  - `.github/workflows/sq-autopilot-hosted-integration.yml`
- Cycle 005 hosted persistence workflow now uses canonical resolver (no candidate scanning):
  - `.github/workflows/cycle-005-hosted-persistence-evidence.yml`

## “Do Not Proceed” Conditions (if encountered later)

- If branch protection is configured to require a hosted integration check, reverse that immediately. Hosted runtime health must not gate code review velocity.
- If the canonical origin is not stable (no fixed production domain), stop and establish one before expanding automation.

## Next Action

Set repo variable `HOSTED_WORKFLOW_BASE_URL` to the single stable deployed runtime origin (one value only), then run `sq-autopilot-hosted-integration` via `workflow_dispatch` once to validate.

