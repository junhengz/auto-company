# Cycle 001 Brainstorm (2026-02-14): Ship a Local-First Workflow Runtime Kit

## One Idea (Exactly One)
**Ship a self-hostable “Workflow Runtime Kit” (Docker/Compose + one-command dev runner) and make it the default for CI preflight and customer pilots.**

Stop treating “hosted workflow base URL candidates” as a thing users (or CI) have to reason about. Instead, make the workflow runtime a predictable, local/private service with a stable URL and an explicit health/status surface.

This converts the current failure mode (ephemeral tunnels poisoning `HOSTED_WORKFLOW_BASE_URL_CANDIDATES`, flaky preflight) into a deterministic system: CI always talks to `http://127.0.0.1:<port>` and customers can run the same runtime in their own environment for pilots.

## User Groups And Scenarios
- Security/Compliance lead (buyer): needs confidence the system is reliable, auditable, and won’t break mid-questionnaire.
- Procurement/Vendor management (operator): needs questionnaires completed quickly, with clear progress and no “blocked by system” surprises.
- DevOps/Platform engineer (implementer): needs something deployable with clear health checks, logs, and a stable endpoint.

Primary scenario:
- A customer starts a pilot, tries to run the “questionnaire workflow,” and expects it to “just work” the same way every time. CI failures delay delivery; runtime instability kills trust.

## Cognitive/Usability Risks (What’s Failing Today)
- **Bad conceptual model:** A list of “base URL candidates” implies the system is inherently unstable and the user should guess which URL is “real.”
- **Hidden system state:** When a tunnel dies, the system appears “broken” with no immediate, user-comprehensible explanation.
- **Error recovery is unclear:** Users can’t easily “reset to a known good state” because “known good” is not a single stable endpoint.

## Design Changes (Don Norman Lens)
- **Affordance:** Replace “candidate URLs” with a single explicit target: `WORKFLOW_BASE_URL`.
- **Feedback:** Add a first-class `GET /health` and a “runtime status” command (`auto workflow status`) that tells you what’s running, where, and why it’s failing.
- **Constraints/error prevention:** CI must not accept non-stable origins (tunnel domains) as inputs for preflight; default to local runtime.
- **Mapping:** Make it obvious that “workflow runtime” is an engine you run (like a DB) and the rest of the product connects to it.

## What We Ship (Concrete)
- A versioned Docker image for the workflow runtime (or a Compose stack if it needs dependencies).
- `docker-compose.workflow.yml` (or `compose.workflow.yml`) that runs the runtime on a stable port.
- A single command entrypoint for developers and CI, e.g. `make workflow-up` + `make workflow-smoke`.
- A documented “pilot deployment” path for customers: run the same kit in their environment, expose only internally, and point the Autopilot control plane at it.
- A hard rule in CI/preflight: do not use `HOSTED_WORKFLOW_BASE_URL_CANDIDATES`; use local runtime only.

## Validation (How We Know This Works In 2 Weeks)
- CI preflight reliability: 20 consecutive runs with zero failures attributable to workflow base URL resolution.
- Smoke test contract: preflight includes `workflow-smoke` that proves start/stop, health, and one representative workflow execution.
- Pilot readiness: one customer (or internal “fake customer” environment) runs the kit without tunnels and completes an end-to-end questionnaire workflow.

## What Could Go Wrong (And How We Contain It)
- Runtime containerization exposes missing implicit dependencies.
  - Containment: bake dependencies into Compose; keep the first version minimal; prioritize health + one workflow path.
- Customers resist running anything new.
  - Containment: position it as “runs inside your network” (security-positive); provide a minimal deployment guide and a single port exposure.
- The product still has scattered code paths that “helpfully” pick a hosted candidate URL.
  - Containment: remove/disable candidate logic from CI and default configuration; make overrides explicit and noisy.

## Execution Plan (5-10 Bullets)
- Identify the minimal workflow runtime surface required for preflight (health + one workflow execution).
- Add a stable local runner: Compose file + `make workflow-up` + `make workflow-down`.
- Add `make workflow-smoke` that blocks until healthy, runs a representative request, and asserts deterministic output.
- Update CI preflight to start the local runtime and set `WORKFLOW_BASE_URL=http://127.0.0.1:<port>` explicitly.
- Remove or gate `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` usage in CI (allow only for manual/dev experimentation behind an explicit flag).
- Add `auto workflow status` (or equivalent) that prints: base URL, health, last error, and how to fix.
- Write a short “Pilot Deployment” doc: recommended topology, ports, and troubleshooting checklist.
- Run one internal pilot end-to-end using the same kit; capture time-to-first-success and failure points.

