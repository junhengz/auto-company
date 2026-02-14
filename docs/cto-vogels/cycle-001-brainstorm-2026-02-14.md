# Cycle 001 Brainstorm (CTO/Vogels): Stabilize Hosted Workflow Runtime + CI (2026-02-14)

## Constraints And Business Requirements
- We need a stable, public `BASE_URL` for the workflow API (`/api/workflow/*`) so Cycle 005 preflight stops failing and customer delivery is not blocked.
- Current failure mode: repo variable `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` gets poisoned with ephemeral tunnel URLs, making CI deterministic-fail until a human fixes it.
- Next ~2 weeks: maximize shipping and revenue impact, not perfect architecture.

## Exactly One Idea
Standardize on **one canonical hosted workflow runtime on Fly.io** (single app name + stable `https://<app>.fly.dev` origin, volume-mounted `/app/runs`), and make CI treat that origin as the only durable source of truth by adding a simple **anti-poisoning guardrail**: only persist/accept `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` values that match an allowlist (initially `*.fly.dev` for the canonical app).

This is intentionally boring: one managed runtime, one stable domain, one place to look when things break.

## What We Ship (Concrete)
- A production-like hosted runtime for `projects/security-questionnaire-autopilot` on Fly.io:
  - App: `auto-company-sq-autopilot` (keep the name stable).
  - Persistent volume: `runs` mounted at `/app/runs` (already in our deployment helper).
  - Endpoint contract:
    - `GET /api/workflow/env-health` returns `ok=true` and required env booleans.
    - `GET /api/workflow/supabase-health` returns `.ok=true` once Supabase schema/seed is applied.
- CI reliability guard:
  - `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` may contain only allowlisted origins (no `*.trycloudflare.com`, no `*.lhr.life`, no ad-hoc tunnels).
  - If a non-allowlisted origin is proposed for persistence, fail fast with a single-line fix instruction.

## How We Validate (Fast, Deterministic)
1. Manual smoke on the canonical origin:
   - `curl -sS https://auto-company-sq-autopilot.fly.dev/api/workflow/env-health | jq .ok`
2. GitHub Actions preflight gate:
   - Run `cycle-005-hosted-persistence-evidence` with `preflight_only=true` and `preflight_require_supabase_health=true`.
   - Success criteria is the uploaded `cycle-005-hosted-preflight` artifact with:
     - `preflight/env-health.json` booleans true
     - `preflight/supabase-health.json` `.ok == true`
3. Failure drills (cheap):
   - Redeploy the Fly app once; confirm `BASE_URL` stays identical and preflight remains green.

## Key Risks / Failure Modes (Everything Fails)
- Fly app becomes a single point of failure if we keep one machine in one region.
- Secrets drift: runtime deployed but missing `NEXT_PUBLIC_SUPABASE_URL` / `SUPABASE_SERVICE_ROLE_KEY`, or Supabase SQL bundle not applied to the intended project.
- Allowlist too strict or misconfigured: blocks legitimate migrations (e.g., moving from Fly to another provider) without an explicit change procedure.
- Operational cost: Fly introduces an ops surface (deploys, volumes, regions) that Vercel-style serverless avoids.

## Technology Recommendation (With Rationale)
- Hosting: **Fly.io** for the workflow runtime in the next 2 weeks.
  - Rationale: stable origin (`*.fly.dev`), supports a persistent volume for `/app/runs`, and matches our existing `scripts/devops/deploy-sq-autopilot-fly-and-preflight.sh` flow.
- Guardrail: simple **domain allowlist** for candidate persistence/selection.
  - Rationale: fastest way to stop CI poisoning without redesigning discovery.

## Execution Plan (7-10 Days Of Work, 2 Weeks Calendar)
1. Deploy canonical runtime to Fly with `scripts/devops/deploy-sq-autopilot-fly-and-preflight.sh` (use real Supabase env when ready).
2. Set repo variable `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` to exactly `https://auto-company-sq-autopilot.fly.dev` (optionally add one backup origin later, but keep it small).
3. Apply Supabase SQL bundle to the target Supabase project; rerun preflight with `preflight_require_supabase_health=true` until green.
4. Add an allowlist check in the persistence path so CI cannot write tunnel domains into `HOSTED_WORKFLOW_BASE_URL_CANDIDATES`.
5. Make the preflight job fail with an explicit, copy/paste remediation when candidates are missing or rejected by allowlist.
6. Add one reliability improvement: scale Fly app to 2 machines (same region first) and verify the health endpoints during a rolling deploy.
7. Run the full evidence job (`preflight_only=false`) once preflight is green; use that output as customer-facing credibility artifact.
8. Write a one-page operator runbook: "what to do when preflight fails" centered on `env-health`, `supabase-health`, and the canonical `BASE_URL`.

Next Action: run `scripts/devops/deploy-sq-autopilot-fly-and-preflight.sh --repo junhengz/auto-company --preflight-require-supabase-health false --no-local-smoke` to establish the canonical `https://auto-company-sq-autopilot.fly.dev` origin and persist it into `HOSTED_WORKFLOW_BASE_URL_CANDIDATES`.

