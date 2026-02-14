# Cycle 013: Fix Probe Report Determinism (Stale body_head)

## Problem

`projects/security-questionnaire-autopilot/scripts/probe-hosted-base-url-candidates.sh` reuses a single temp body file for all candidates.

If `curl` fails before writing the response body (common case: DNS failure), the script could report a `body_head` from the previous candidate, which makes the probe table misleading and non-deterministic.

Example failure mode:

- candidate A: Vercel `DEPLOYMENT_NOT_FOUND` (body has text)
- candidate B: DNS failure (no body written)
- probe output for candidate B incorrectly includes candidate A's `body_head`

## Fix

Before probing each candidate, truncate the temp files:

- `: >"$out"`
- `: >"$hdr"`

Also avoid `000000` double-printing by setting a default HTTP code without `|| echo "000"` concatenation.

## Verification Command

```bash
./projects/security-questionnaire-autopilot/scripts/probe-hosted-base-url-candidates.sh \
  "https://auto-company.vercel.app https://security-questionnaire-autopilot-hosted.pages.dev"
```

Expected now:

- the DNS-failing candidate reports `http=000` and an empty `note` (no stale `body_head` leak).

