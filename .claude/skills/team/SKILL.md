---
name: team
description: "Quickly assemble a temporary AI agent team for a task by selecting the best-fit members from .claude/agents/."
argument-hint: "[task description]"
disable-model-invocation: true
---

# Assemble A Temporary Team

Based on the task below, select the most suitable agents from the company roster and form a temporary execution team.

## Task

$ARGUMENTS

## Available Agents

All agents are defined in `.claude/agents/`:

| Agent | File | Responsibility |
|-------|------|------|
| CEO | `ceo-bezos` | strategy, business model, PR/FAQ, prioritization |
| CTO | `cto-vogels` | architecture, tech choices, systems design |
| Critic | `critic-munger` | challenge assumptions, find fatal flaws, pre-mortem |
| Product Design | `product-norman` | product definition, UX, usability |
| UI Design | `ui-duarte` | visual design, design system, typography/color |
| Interaction Design | `interaction-cooper` | user flows, personas, interaction patterns |
| Full-stack Development | `fullstack-dhh` | implementation, engineering plan, coding |
| QA | `qa-bach` | test strategy, quality risk, bug analysis |
| DevOps/SRE | `devops-hightower` | CI/CD, infrastructure, monitoring, reliability |
| Marketing | `marketing-godin` | positioning, brand, acquisition, content |
| Operations | `operations-pg` | growth ops, retention, community, PMF execution |
| Sales | `sales-ross` | funnel strategy, conversion, sales process |
| CFO | `cfo-campbell` | pricing, financial model, cost control, unit economics |
| Research | `research-thompson` | market/competitor analysis, trend and opportunity discovery |

## Execution Steps

### 1. Analyze the task and select members

Choose 2-5 most relevant agents.

Selection rules:
- **Need only**: more people is not better; precision matters
- **Coverage chain**: if task spans design -> build -> launch, include critical handoff roles
- **No redundancy**: avoid overlapping responsibilities

Briefly tell the founder who you selected and why, then start execution immediately.

### 2. Build the Agent Team

Use Agent Teams to create a temporary team:
- Create a team with a short English `team_name` in `kebab-case`
- Create clear, context-rich tasks for each member (`TaskCreate`)
- Spawn each teammate via Task tool with `subagent_type=general-purpose`
- Inject the full corresponding agent profile file into each teammate prompt
- Tell each teammate their role, required output, and required output folder `docs/<role>/`

### 3. Coordinate and synthesize

- Lead and coordinate work across teammates
- Collect outputs and synthesize into one clear plan/result
- If disagreement exists, list viewpoints and decision tradeoffs explicitly
- Clean up temporary team resources after completion

## Notes

- Use clear English for all communications
- Store each member's outputs in `docs/<role>/`
- Team is temporary and should be dissolved after task completion
- Founder is the final decision-maker; agents advise, they do not override
