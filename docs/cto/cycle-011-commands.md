# Cycle 011: Commands (Copy/Paste)

Date: 2026-02-14

## Confirm Which Repo Has The Workflow
```bash
gh workflow list -R nicepkg/auto-company || true
gh workflow list -R junhengz/auto-company || true
```

## Probe Candidate Origins Locally (Fast Reality Check)
```bash
./projects/security-questionnaire-autopilot/scripts/probe-hosted-base-url-candidates.sh \
  "https://candidate1 https://candidate2 https://candidate3"
```

## Persist Candidates (Recommended)
```bash
gh variable set HOSTED_WORKFLOW_BASE_URL_CANDIDATES -R junhengz/auto-company --body \
  "https://candidate1 https://candidate2"
```

## Run Preflight Only (No Evidence, No PR)
```bash
./scripts/devops/run-cycle-005-hosted-persistence-evidence.sh \
  --repo junhengz/auto-company \
  --preflight-only
```

## Run Full Evidence (After Green Preflight)
```bash
./scripts/devops/run-cycle-005-hosted-persistence-evidence.sh \
  --repo junhengz/auto-company
```

## Provider-First Autodiscovery (If You Have Tokens/IDs Locally)
Vercel:
```bash
export VERCEL_TOKEN="..."
export VERCEL_PROJECT_ID="..."   # or VERCEL_PROJECT="name"
./projects/security-questionnaire-autopilot/scripts/collect-base-url-candidates-from-vercel-api.sh
```

Cloudflare Pages:
```bash
export CLOUDFLARE_API_TOKEN="..."
export CLOUDFLARE_ACCOUNT_ID="..."
export CF_PAGES_PROJECT="..."
./projects/security-questionnaire-autopilot/scripts/collect-base-url-candidates-from-cloudflare-pages-api.sh
```

