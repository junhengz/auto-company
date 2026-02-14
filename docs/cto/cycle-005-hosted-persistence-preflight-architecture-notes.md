# Cycle 005 Hosted Persistence Preflight: Architecture Notes (CTO)

Date: 2026-02-14
Repo target: `junhengz/auto-company`
Command attempted:
`./scripts/devops/run-cycle-005-hosted-persistence-evidence.sh --repo junhengz/auto-company --autodiscover-github --preflight-only --skip-sql-apply true`

## Observed Outcome (Preflight-Only, Autodiscover GitHub)

The preflight did **not** dispatch a GHA run because it could not resolve any hosted runtime `BASE_URL` candidates:

- Failure: `Missing BASE_URL candidates.`
- Root cause: no repo variable `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` was found, and GitHub Deployments metadata discovery returned no URLs (common when the repo/host integration does not publish Deployments status `environment_url`/`target_url`).

This is an expected failure mode for `--autodiscover-github`: it is best-effort and frequently yields zero candidates.

## System Contract (What The Gate Is Trying To Prove)

The preflight gate is intended to deterministically prove:

1. We have a valid deployed **Next.js workflow runtime** (not a marketing/static domain):
   - `GET <BASE_URL>/api/workflow/env-health` returns HTTP 200 JSON with `ok:true`.
2. The deployed runtime has required hosted Supabase env vars present (booleans only; no secrets):
   - `env.NEXT_PUBLIC_SUPABASE_URL == true`
   - `env.SUPABASE_SERVICE_ROLE_KEY == true`
3. (Stronger signal) The runtime can actually reach the intended Supabase project with expected schema/seed:
   - `GET <BASE_URL>/api/workflow/supabase-health?requireSeed=1&requirePilotDeals=1` returns `{ ok:true }`

Operationally, the wrapper script tries to fail fast locally before spending CI cycles, and refuses to dispatch unless it can select/probe a usable `BASE_URL` (unless an operator explicitly bypasses local probing).

## Risks / Failure Modes

### A) Base-URL Candidate Resolution (Most Common Break)

- No candidates exist anywhere:
  - Repo variable `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` is missing.
  - Operator did not pass `--base-url`/`--candidates`.
  - GitHub Deployments metadata is absent (or doesn’t include usable URLs).
  - Result: hard stop before dispatch (current behavior).

- Candidates exist but are not deterministically “the right runtime”:
  - Candidates include marketing/static sites that return HTML, redirects, or 404 for `/api/workflow/env-health`.
  - Candidates include preview/PR deployments that are “healthy” but not the intended production runtime.
  - Candidates include legacy domains that still serve an older build lacking the required routes.
  - Candidates include a path/query; scripts normalize to origin, which can hide a mis-copied URL (“it worked once” illusions).

- Autodiscovery nondeterminism:
  - GitHub Deployments statuses are not guaranteed to be ordered by “most recent production”.
  - `environment_url`/`target_url` may point to ephemeral preview URLs, aliases, or stale runs.
  - Even when discovery returns data, the final choice is “first candidate that passes the probe”, which can change when provider aliases change.

### B) Local Probe vs CI Probe Disagreements

- Operator machine network differences:
  - VPN, corporate network, DNS split-horizon, or outbound filtering can prevent reaching the deployed runtime.
  - Local probe fails and script refuses to dispatch; operator may bypass via `--no-local-probe`, shifting the failure into CI and reintroducing nondeterminism (CI may pick a different reachable candidate).

- Timeouts / transient failure:
  - The probe uses short timeouts (`curl -m 12`). A cold start or edge delay can cause false negatives.
  - A “flaky but correct” runtime can cause repeated failed dispatch attempts.

### C) env-health Check Limitations

- env-health is an identity probe, not a correctness proof:
  - It validates that the route exists and that env vars are *present* (booleans), but it does not prove:
    - the Supabase URL points to the intended project,
    - the service role key is valid,
    - schema/seed is applied.
  - The wrapper partially addresses this with a `supabase-health` check (when local smoke is enabled), but this is still subject to network reachability and endpoint implementation drift.

### D) Wrong-Environment Blast Radius

If the wrong `BASE_URL` is selected (especially a healthy preview deployment):

- Evidence can be generated against the wrong Supabase project (if the preview points to a different DB).
- The “pass” signal becomes non-actionable, and we train operators to distrust the gate.
- If scheduled runs are enabled based on a green preflight, the system can repeatedly exercise the wrong environment.

## Hardening Improvements (Keep The Gate Deterministic)

### 1) Pin a Single “Primary Runtime” and Make Autodiscovery Suggest-Only

Goal: deterministic behavior across operators and time.

- Introduce a single pinned variable (conceptually):
  - `HOSTED_WORKFLOW_BASE_URL_PRIMARY=<origin>`
  - and treat `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` as a fallback hint list only.
- Make autodiscovery (`--autodiscover-github/--autodiscover-hosting`) produce *recommendations*:
  - Print the copy/paste `gh variable set ...` command and exit non-zero unless the operator explicitly persists.
  - Operational effect: no more “it dispatched against something discovered at runtime”; you always converge to an explicit pinned value.

Why this helps: autodiscovery sources are inherently unstable; pinning makes the gate repeatable and auditably intentional.

### 2) Strengthen Runtime Identity: Add a Stable “Runtime-ID” Contract Used for Selection

Goal: choose the correct runtime deterministically even when multiple candidates answer `env-health`.

Extend `GET /api/workflow/env-health` (or add `GET /api/workflow/runtime-id`) to include **non-secret** identity fields, for example:

- `app_id`: constant identifier (e.g. `security-questionnaire-autopilot`)
- `env_kind`: `production|preview|unknown`
- `git_sha`: deployed commit SHA
- `schema_bundle_id` (or equivalent) if available safely
- `supabase_project_ref` (or a safe derived ID) if available

Selection rule becomes deterministic:

- Prefer `env_kind=production`, and optionally require `app_id` match.
- If multiple production candidates exist, prefer the newest `git_sha` (or an explicit `deployment_id`), not “first probe success”.

Why this helps: it reduces the risk of silently selecting a preview environment that happens to be healthy.

## Next Action

Set `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` for `junhengz/auto-company` (2-4 production candidate origins), then re-run:
`./scripts/devops/run-cycle-005-hosted-persistence-evidence.sh --repo junhengz/auto-company --preflight-only`

