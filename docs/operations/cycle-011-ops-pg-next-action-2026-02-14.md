# Cycle 011 (Operations/PG): Next Action (2026-02-14)

## Next Action
Have a maintainer provide 2-4 **real production** hosted workflow origins (Vercel/Pages) that serve `/api/workflow/*`, then set:

```bash
REPO="OWNER/REPO"
gh variable set HOSTED_WORKFLOW_BASE_URL_CANDIDATES -R "$REPO" --body "https://<origin1> https://<origin2>"
./scripts/devops/run-cycle-005-hosted-persistence-evidence.sh --repo "$REPO" --preflight-only
```

If you cannot reliably get those origins from humans, instead configure provider-backed discovery inputs (Vercel or Cloudflare) and rerun with `--autodiscover`.

