# Skills Architecture

Skills are procedural guides that provide step-by-step workflows for complex operations. They are lazy-loaded into Claude's context only when relevant to the current task.

## Skills (condensed — see references/skill-inventory.md for full inventory)

All skills are agent-loaded (not invoked directly). See [references/skill-inventory.md](references/skill-inventory.md) for full details.

**Deployment / K8s**: `deploy-app`, `flux-gitops`, `app-template`, `k8s`, `gateway-routing`, `network-policy`, `cnpg-database`, `secrets`
**Infrastructure**: `terragrunt`, `opentofu-modules`, `versions-renovate`, `gha-pipelines`
**Observability**: `monitoring-authoring`, `grafana-dashboards`, `prometheus`, `loki`, `sre`
**Research / Authoring**: `kubesearch`, `taskfiles`, `architecture-review`
**Pipeline / Ops**: `promotion-pipeline`, `security-testing`, `self-improvement`, `sync-claude`, `instruction-eval`

## Commands (User Entry Points)

User-invocable slash commands live in `.claude/commands/` and dispatch to specialized agents:

| Command | Dispatches To | Purpose |
|---------|--------------|---------|
| `/troubleshoot` | `troubleshooter` agent | Kubernetes and infrastructure debugging |
| `/implement` | `implementer` agent | Deploy apps, write IaC, create PRs |
| `/design` | `designer` agent | Architecture design and review |

Commands are simple markdown files — no YAML frontmatter. They contain a prompt that delegates to the corresponding agent.

## Skill vs Command vs CLAUDE.md Boundary

| Type | Location | Purpose | Content |
|------|----------|---------|---------|
| **CLAUDE.md** | Throughout repo | Declarative knowledge | What exists, why, constraints, anti-patterns |
| **Skills** | `.claude/skills/` | Procedural knowledge | Step-by-step workflows, decision trees |
| **Commands** | `.claude/commands/` | User entry points | Dispatch prompts to agents |
| **Runbooks** | `docs/runbooks/` | Emergency procedures | Incident response, disaster recovery |

## Agent-First Architecture

This repository uses an **agent-first** interaction model. Users interact through 3 high-level commands (`/troubleshoot`, `/implement`, `/design`) that dispatch to specialized agents. Skills serve as background knowledge that agents compose internally.

Agents are defined in `.claude/agents/`:

| Agent | Role | Model | Mode |
|-------|------|-------|------|
| `troubleshooter` | SRE debugging specialist | inherit | read-only |
| `implementer` | Platform engineer | inherit | full tools |
| `designer` | Principal architect | opus | plan (read-only) |
| `security-tester` | Adversarial red team tester | opus | read-only |

For creating a new skill, follow the skill-creator skill. Full checklist and deprecation procedure: see `references/skill-authoring.md`.
