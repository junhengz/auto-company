# Cycle 005: Hosted BASE_URL Discovery (Operations Runbook)

Date: 2026-02-14
Owner: operations-pg
Scope: `projects/security-questionnaire-autopilot` hosted Next.js workflow runtime (`/api/workflow/*`)

## What We Need (Definition of "Authoritative Production Domain")

Cycle 005 preflight needs **1+ HTTPS origins** (no path, no trailing slash) that point to the deployed Next.js runtime serving:

- `GET <BASE_URL>/api/workflow/env-health` -> `200` JSON with `.ok == true`

If that endpoint returns HTML, `404`, or `DEPLOYMENT_NOT_FOUND`, the domain is not the workflow runtime (common failure: marketing/static site or stale preview URL).

## Why This Is an Ops Problem (Not Derivable From Code)

The deployed `BASE_URL` is **deployment-specific** and often lives behind:

- Vercel project settings (production + custom domains)
- Cloudflare Pages project settings (production + custom domains)
- Organization DNS/registrar settings (CNAMEs/ALIAS records)

In the current GitHub repo context, Deployments metadata may be empty, so autodiscovery can return no candidates. When that happens, the only reliable source is the person/team that owns the hosting account.

Operational note: `junhengz/auto-company` is a fork of `nicepkg/auto-company`, and forks commonly have no Deployments metadata or Actions variables configured, so treat the upstream repo as the likely "canonical" workflow runner.

## Who To Ask (Fastest Path To Truth)

Ask the smallest set of people who can answer in one message:

- Hosting owner: whoever can open the Vercel/Cloudflare project dashboard and see "Domains" for Production.
- DNS owner: whoever controls the custom domain in the registrar/DNS provider (if a vanity domain exists).
- GitHub repo admin: whoever can set Actions variables in the canonical repo that runs Cycle 005.

If names are unknown, use these heuristics:

- Check who deployed last: look for recent deploy/release notes in team chat, or the person who merged the deploy PR.
- If Vercel is used: ask who has access to the Vercel team/workspace for the project.
- If Cloudflare Pages is used: ask who owns the Cloudflare account + Pages project.

## What To Ask For (One-Screen Request Template)

Request:

1. "Send 2-4 **production** origins (not preview) for the deployed workflow runtime that serves `GET /api/workflow/env-health`."
2. "For each origin, confirm whether it is: `production`, `staging`, or `preview`."
3. "Tell me the hosting provider and project identifier:"
4. "Confirm whether the following are set on the hosted runtime (Production env): `NEXT_PUBLIC_SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`."

Minimal acceptable answer (unblocks preflight):

- At least 1 origin that returns `200` JSON for `/api/workflow/env-health`.

## How To Identify the Production Domains (Per Provider)

### Vercel

In Vercel UI:

1. Open the project that deploys the Next.js app containing `app/api/workflow/*`.
2. Go to `Settings -> Domains` and copy:
3. The `*.vercel.app` production domain.
4. Any custom domains attached to Production.

Avoid:

- Preview deployment URLs (commit/branch scoped).
- Unrelated domains for a marketing site.

### Cloudflare Pages

In Cloudflare Pages UI:

1. Open the Pages project.
2. Copy the `*.pages.dev` production domain.
3. Copy any custom domains bound to the project (Production).

Avoid:

- A `pages.dev` site that is static/marketing and does not serve `/api/workflow/*`.

## Validate Before Recording (No Guesswork)

For each candidate origin:

```bash
BASE_URL="https://candidate.example.com"
curl -sS "$BASE_URL/api/workflow/env-health" | jq .
```

Pass criteria:

- HTTP `200`
- JSON
- `.ok == true`

For Cycle 005 evidence (not just discovery), you typically also need:

- `.env.NEXT_PUBLIC_SUPABASE_URL == true`
- `.env.SUPABASE_SERVICE_ROLE_KEY == true`

## System of Record (How To Record and Maintain Candidates)

Authoritative store (what the workflow reads):

- GitHub Actions variable `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` in the canonical repo that dispatches Cycle 005, e.g.:
- `HOSTED_WORKFLOW_BASE_URL_CANDIDATES="https://u1 https://u2 https://u3"`

Operational hygiene (prevents regressions):

- Keep 2-4 candidates max (custom domain + provider default domain + 1 backup).
- Add a "last verified" timestamp in the variable description (or in a short ops note).
- Re-verify after:
  - domain changes
  - hosting migration
  - major redeploy changes

If you cannot edit repo variables directly:

- You can still unblock a single run by passing `--base-url "..."` to the runner script (no persistence).
- Or dispatch with `persist_base_url_candidates=true` (if the workflow is allowed to write variables).

## Minimum Info Needed to Unblock Cycle 005 Preflight

You can make preflight green with:

1. One valid `BASE_URL` origin for the workflow runtime (validated via `/api/workflow/env-health`).
2. The ability to provide that origin to the workflow (either):
3. Set `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` in the canonical repo, or
4. Dispatch with `--base-url "https://..."` for a one-off run.

If preflight is green but evidence fails next:

- The hosted runtime likely lacks required Supabase env vars, or points at the wrong Supabase project.
