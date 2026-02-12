# Indie Hackers Post: CronPulse

> **Author**: operations-pg (Paul Graham model)
> **Date**: 2026-02-12
> **Platform**: Indie Hackers
> **Purpose**: Build-in-public post to collect feedback and find early users
> **Updated**: Cycle 28 — reflects current product state

---

## Title

**I built a cron monitoring SaaS for $6/month in infrastructure. Here's the full cost breakdown.**

---

## Post Body

Every developer has a cron job horror story. Mine was a database backup script that silently stopped running after a system update. I found out 11 days later when I actually needed the backup. The backup was gone. The script was broken. Nobody told me.

The fix is simple: add a monitoring ping at the end of your cron script. If the ping stops arriving, you get an alert. Services like Healthchecks.io and Cronitor have been doing this for years and they're solid tools. But I kept looking at the infrastructure and thinking: this should cost almost nothing to run.

So I built CronPulse.

**The entire setup runs on Cloudflare Workers.** No VPS. No Docker. No server to maintain. One Cloudflare Worker handles everything -- the API, the dashboard, the ping endpoint, the alerting engine.

### Why Cloudflare Workers?

This is the part that might interest people here who are thinking about their own SaaS cost structure.

Most cron monitoring tools run on traditional servers. Healthchecks.io runs on a Hetzner bare-metal box. Cronitor runs on AWS. That's fine, but it means you're paying for servers whether you have 0 users or 10,000 users.

Cloudflare Workers pricing is usage-based. Here's my actual cost breakdown:

| Item | Monthly Cost |
|------|-------------|
| Workers Paid Plan (compute + routing) | $5.00 |
| Domain (cron-pulse.com via Cloudflare Registrar) | ~$0.92 |
| D1 database (SQLite at the edge) | $0 (included) |
| KV cache | $0 (included) |
| Cron Triggers (overdue checking every minute) | $0 (included) |
| **Total** | **~$6/month** |

That $6 covers everything: the monitoring engine, the web dashboard, the REST API, the blog, and the landing page. D1 gives me 50 million row writes per month for free. At my current scale, that's essentially unlimited.

### The math that matters

My pricing is $5/month for 50 checks, $15/month for 200, and $49/month for 1,000. Free tier gets 10 checks.

If I get 2 paying customers on the $5 plan, I've covered my infrastructure. Two customers. That's ramen profitability at its most literal -- except it's more like a single cup of coffee profitability.

At 60 paying users with a realistic plan mix (60% Starter, 30% Pro, 10% Business), I'd be at roughly $500/month MRR. The gross margin at that point would be above 97%. That's not a typo. When your infrastructure costs $6 and your revenue is $500, almost everything is profit.

For comparison, here's what competing services charge:

| Service | 50 checks/month | 200 checks/month |
|---------|----------------|------------------|
| CronPulse | $5 | $15 |
| Healthchecks.io | $20 | $80 |
| Cronitor | ~$100 | ~$400 |
| Dead Man's Snitch | ~$15 | ~$49 |

I'm not saying CronPulse is better than these tools. Healthchecks.io has 25+ notification integrations and 10 years of trust. Cronitor has enterprise features. But if you need straightforward cron monitoring and you care about the price, there's room in the market.

### Why I priced it this way

The $5 starting price is deliberate. I want the decision to be a non-decision. Five dollars is low enough that a solo developer doesn't need to think about it, doesn't need to ask for budget approval, and doesn't need to comparison shop. Just pay and move on.

The jump to $15 for 200 checks catches teams that outgrow the starter plan. And $49 for 1,000 checks is for people running serious infrastructure but who don't want to pay enterprise prices.

I specifically avoided per-monitor pricing (like Cronitor's $2/monitor) because it creates anxiety. "Do I really need this check? Is it worth $2/month?" I don't want users thinking about that. Flat tiers, simple math.

### What's in the box

CronPulse is a lot more than just a ping endpoint now:

- **One-line integration** — `curl -fsS https://cron-pulse.com/ping/YOUR_ID`. That's the entire setup.
- **Start/Success/Fail signals** — Track job duration, not just completion. Know when a job started but never finished.
- **Cron expression parsing** — Paste `0 2 * * *` and it auto-calculates the expected interval.
- **CLI tool** — `npx cron-pulse-cli init "Backup" --every 1h` creates a check and outputs a ready-to-use crontab line.
- **GitHub Action** — Monitor CI/CD scheduled workflows with one YAML step.
- **Email, Slack, Webhook alerts** — Email via Resend (HTML templates), Slack with Block Kit, webhooks with HMAC signing.
- **Status badges** — Embed live status SVGs in your README.
- **Public status pages** — Share uptime with your users, grouped by service.
- **Check groups and tags** — Organize hundreds of checks.
- **Incident timeline** — Full history of downs and recoveries.
- **Maintenance windows** — Suppress alerts during planned downtime (recurring supported).
- **REST API** — Manage everything programmatically.
- **Import/Export** — Backup your config as JSON.

### What I deliberately did NOT build

- **No SDK.** Just curl. The simplest possible integration.
- **No team management (yet).** This is a tool for individual developers and small teams.
- **No mobile app.** Alerts find you via email/Slack/webhook.
- **No AI anything.** "AI-powered cron monitoring" is a solution looking for a problem.

Every feature I skipped was a feature I wanted to build. Shipping meant being ruthless about scope.

### Current status: honest numbers

- **Revenue**: $0
- **Users**: 0
- **Stage**: Production (live at cron-pulse.com with custom domain)
- **Time to build**: ~2 weeks from first line of code to production
- **Infrastructure cost**: ~$6/month
- **Notification channels**: Email (Resend), Slack (Block Kit), Webhooks (HMAC signed)

I'm not going to pretend this is further along than it is. The product works and is feature-complete for a v1. You can sign up, create checks, send pings, and receive alerts. But I have zero users, and I'm posting here because I genuinely want feedback.

### Open source

The entire codebase is open source under AGPL-3.0: https://github.com/nicepkg/cronpulse

You can read every line, self-host on your own Cloudflare account, or contribute. I've tagged Good First Issues for anyone interested. The CLI and GitHub Action are MIT licensed.

### Questions for this community

I'd appreciate honest answers on any of these:

1. **Is $5/month for 50 checks the right entry price?** Too low and it signals low quality. Too high and it's not the no-brainer I want it to be.
2. **Is 10 free checks enough?** Healthchecks.io gives 20 for free. I went with 10 because I think it covers a typical personal server setup, but I might be wrong.
3. **Would you trust a monitoring service running on someone else's platform (Cloudflare)?** The upside is zero ops on my end. The downside is platform dependency. How much does that matter to you?
4. **What's the one feature that would make you switch from whatever you're using now?**

Here's the product: https://cron-pulse.com?utm_source=indiehackers&utm_medium=social&utm_campaign=launch-2026-02

Thanks for reading. Happy to answer anything about the tech stack, the business model, or the build process.

---

## Posting Notes

### Why This Post Works for Indie Hackers

1. **Leads with cost structure.** IH readers obsess over unit economics. The $6/month infrastructure number is the hook that makes people read the rest.
2. **Full transparency on revenue ($0).** IH culture rewards honesty. Saying "$0 revenue" is more credible than saying "pre-revenue" or "early traction."
3. **Shows the math.** Ramen profitability at 2 customers. 97% margins at scale. These are the numbers IH readers run in their heads.
4. **Competitive comparison without trash-talking.** Acknowledging Healthchecks.io and Cronitor as solid tools while showing the price gap.
5. **"What I did NOT build" section.** IH readers who have built products know that scope discipline is harder than coding. This section signals experience.
6. **Specific questions at the end.** Not "what do you think?" but targeted questions that invite substantive responses.
7. **No exclamation marks. No hype.** Just numbers, reasoning, and an invitation to poke holes.

### Expected Comments and Response Strategy

| Expected Comment | Response Approach |
|-----------------|-------------------|
| "Why not just use Healthchecks.io?" | Respect it. 10 years, open source, great tool. CronPulse is for people who want lower prices in the 50-200 check range and zero-ops architecture. Different tradeoffs, not "better." |
| "Your pricing is too low" | Maybe. Starting low is intentional -- I'd rather earn trust and raise prices later than start high and get nobody. The margins support it because my infra cost is $6. |
| "$0 revenue, why should I care?" | Fair. The point of this post is to share the build and get feedback, not to brag about revenue. Revenue comes from users, and users come from making something worth using. |
| "What if Cloudflare raises prices?" | Even if they doubled everything, my cost goes from $6 to $12. At 97% margins, I can absorb a lot of price increases. |
| "10 free checks isn't enough" | Tell me what would be. I'm genuinely calibrating this. If most people need 15-20 for personal use, I want to know now. |
| "How do you plan to get users?" | This post. HN Show HN. Reddit dev communities. SEO blog content. No paid ads. For a $5/month product, CAC needs to be close to zero. |
| "Cool, I'm building something similar" | Genuine interest. Ask about their approach. IH is a community, not a competition. |

### Posting Time

- **Best time**: Tuesday or Wednesday, 9:00-10:00 AM ET
- **Why**: IH is most active during US business hours early in the week
- **Do not post on**: Friday (low engagement) or weekends (lower traffic on IH vs Reddit)

### Post-Publish Checklist

- [ ] Reply to every comment within 2 hours
- [ ] Upvote thoughtful critical comments
- [ ] If someone shares their own project, engage genuinely
- [ ] Track signups that come in during the 48 hours after posting
- [ ] Note every piece of feedback in a spreadsheet (feature requests, objections, praise, bugs)
- [ ] Do not edit the post after publishing (except typos)
- [ ] Do not ask for upvotes or engagement

---

> **Document**: `docs/operations/indie-hackers-post.md`
> **Version**: v2.0 (Cycle 28 — updated to reflect current product state)
> **Related**: `docs/operations/community-launch-posts.md` (HN + Reddit posts)
