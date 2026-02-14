# Next Action (Cycle 005 Supabase)

Set required GitHub Actions secrets in `junhengz/auto-company`, then run the Cycle 005 workflow and assert `supabase-verify.json` is `ok=true`.

- `SUPABASE_ACCESS_TOKEN`
- `SUPABASE_ORG_SLUG`
- `SUPABASE_DB_PASSWORD`

Fast path (interactive; prompts securely on a TTY):

```bash
cd /home/zjohn/autocomp/auto-company
scripts/devops/gh-ensure-supabase-provision-secrets.sh --repo junhengz/auto-company --set-missing
scripts/devops/run-cycle-005-supabase-provision-apply-verify.sh --repo junhengz/auto-company --reuse-existing true
```

Runbook: `docs/devops-hightower/cycle-005-supabase-provision-apply-verify-unblock-2026-02-14.md`

---

# Next Action (Hosted Origin on Fly)

Establish the stable hosted runtime origin for Cycle 005:

1. Acquire Fly auth for non-interactive deploys:
   - set `FLY_API_TOKEN` (recommended), or run `~/.fly/bin/flyctl auth login` interactively
2. Deploy `projects/security-questionnaire-autopilot` to Fly app `auto-company-sq-autopilot` with real Supabase env:
   - `NEXT_PUBLIC_SUPABASE_URL`
   - `SUPABASE_SERVICE_ROLE_KEY`
3. Rerun `cycle-005-hosted-persistence-evidence` with `local_runtime=false` and `preflight_require_supabase_health=true`.

Runbook: `docs/devops-hightower/2026-02-14-sq-autopilot-fly-deploy-and-cycle-005-rerun-runbook.md`
