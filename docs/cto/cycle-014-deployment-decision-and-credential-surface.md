# Cycle 014 CTO Note: Deployment Decision And Credential Surface

Date: 2026-02-14

Product repo: `junhengz/security-questionnaire-autopilot` (`/home/zjohn/autocomp/security-questionnaire-autopilot`)

## Why We Are Blocked

Cycle 005 preflight is designed to be strict:
- It will not pass unless the hosted runtime is reachable *and* Supabase health checks pass (schema bundle id + seed row checks).

In this environment, we currently have:
- No deployed runtime BASE_URL candidates
- No Supabase project credentials (`NEXT_PUBLIC_SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_DB_URL`)
- No hosting provider automation credentials (`VERCEL_TOKEN` / `CLOUDFLARE_API_TOKEN`)

## Recommended Hosting Decision

Use **Vercel** for the Next.js hosted runtime.

Rationale:
- The product is a Next.js App Router app with API routes (`/api/workflow/*`), which maps cleanly to Vercel’s deployment model.
- Existing automation supports Vercel env upsert + redeploy (best-effort) when tokens/ids are provided.

Cloudflare Pages remains a viable secondary option, but requires more operator involvement for redeploy triggers unless a deploy hook is configured.

## Credential Surfaces (Explicit Boundaries)

1) Hosting provider env vars (authoritative for runtime behavior):
- `NEXT_PUBLIC_SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

These must be set on the deployed app environment (Production at minimum), then redeployed.

2) GitHub Actions secrets (automation and fallback):
- For SQL apply automation (only when `skip_sql_apply=false`): `SUPABASE_DB_URL`
- For CI runtime env-sync automation (Vercel/Cloudflare): `NEXT_PUBLIC_SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`
- For provider automation:
  - Vercel: `VERCEL_TOKEN` + vars `VERCEL_PROJECT_ID|VERCEL_PROJECT` (+ optional team ids)
  - Cloudflare Pages: `CLOUDFLARE_API_TOKEN` + vars `CLOUDFLARE_ACCOUNT_ID`, `CF_PAGES_PROJECT` (+ optional deploy hook secret)

3) GitHub Actions variables (deterministic BASE_URL selection):
- `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` (2-4 origins; treat as “source of truth”)

## Hard Acceptance For “Deployed Runtime Exists”

The only accepted contract is:
- `GET <BASE_URL>/api/workflow/env-health` returns `200` JSON with `.ok == true`
- and for Cycle 005 evidence: `.env.NEXT_PUBLIC_SUPABASE_URL == true` and `.env.SUPABASE_SERVICE_ROLE_KEY == true`

This avoids “marketing domain” mixups and stale preview domains.

## Next Action

Choose Vercel as the canonical hosting provider, deploy `junhengz/security-questionnaire-autopilot`, then set hosted env vars (`NEXT_PUBLIC_SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`) and apply the shipped Supabase SQL bundle; once that’s true, Cycle 005 preflight can be made green deterministically.

