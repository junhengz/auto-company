# Cycle 005: Supabase Credentials Needed (Unblock Checklist)

This workspace currently has:
- no Supabase CLI installed (not required)
- no `psql` installed (not required)
- no `SUPABASE_*` env vars present in the shell

To provision/apply deterministically, provide the following values via your secret manager (names only here):

## Hosted Runtime (Deployment Platform)

- `NEXT_PUBLIC_SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

These must be set on the deployed Next.js runtime that serves `/api/workflow/*`, then redeployed.

## SQL Apply (Choose One)

If using Supabase Dashboard SQL Editor:
- No additional secrets required (you just need Dashboard access)

If using CI or local automation:
- `SUPABASE_DB_URL`

## Optional (Only If Automating Env Sync/Redeploy via CI)

- Vercel: `VERCEL_TOKEN` plus `VERCEL_PROJECT_ID` (or `VERCEL_PROJECT`)
- Cloudflare Pages: `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`, `CF_PAGES_PROJECT`

