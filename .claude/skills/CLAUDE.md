# Skills Architecture

Skills are procedural guides that provide step-by-step workflows for complex operations. They are lazy-loaded into Claude's context only when relevant to the current task.

---

## Skills (condensed — see references/skill-inventory.md for full inventory)

All skills are agent-loaded (not invoked directly). See [references/skill-inventory.md](references/skill-inventory.md) for full details.

**Deployment / K8s**: `deploy-app`, `flux-gitops`, `app-template`, `k8s`, `gateway-routing`, `network-policy`, `cnpg-database`, `secrets`
**Infrastructure**: `terragrunt`, `opentofu-modules`, `versions-renovate`, `gha-pipelines`
**Observability**: `monitoring-authoring`, `grafana-dashboards`, `prometheus`, `loki`, `sre`
**Research / Authoring**: `kubesearch`, `taskfiles`, `architecture-review`
**Pipeline / Ops**: `promotion-pipeline`, `security-testing`, `self-improvement`, `sync-claude`, `instruction-eval`

---

## Commands (User Entry Points)

User-invocable slash commands live in `.claude/commands/` and dispatch to specialized agents:

| Command | Dispatches To | Purpose |
|---------|--------------|---------|
| `/troubleshoot` | `troubleshooter` agent | Kubernetes and infrastructure debugging |
| `/implement` | `implementer` agent | Deploy apps, write IaC, create PRs |
| `/design` | `designer` agent | Architecture design and review |

Commands are simple markdown files — no YAML frontmatter. They contain a prompt that delegates to the corresponding agent.

---

## What is a Skill?

Skills are **procedural knowledge** documents that guide Claude through multi-step workflows. They exist separately from CLAUDE.md files because:

1. **Lazy Loading**: Skills are only loaded when triggered, preserving context window for actual work
2. **Workflow Focus**: Skills describe HOW to do something step-by-step, not what exists or why
3. **Reusable Procedures**: Common operations are codified once and invoked by name
4. **Supporting Resources**: Skills can include reference docs and helper scripts

---

## Skill vs Command vs CLAUDE.md Boundary

| Type | Location | Purpose | Content |
|------|----------|---------|---------|
| **CLAUDE.md** | Throughout repo | Declarative knowledge | What exists, why, constraints, anti-patterns |
| **Skills** | `.claude/skills/` | Procedural knowledge | Step-by-step workflows, decision trees |
| **Commands** | `.claude/commands/` | User entry points | Dispatch prompts to agents |
| **Runbooks** | `docs/runbooks/` | Emergency procedures | Incident response, disaster recovery |

### Decision Tree

```
Is this knowledge...

├─ About what exists and why?
│  └─ CLAUDE.md (declarative)
│     Examples: Architecture overview, configuration structure, constraints
│
├─ A multi-step procedure (5+ steps)?
│  └─ Skill (procedural)
│     Examples: "How to deploy an app", "How to debug K8s issues"
│
├─ A user-facing entry point that dispatches to an agent?
│  └─ Command (.claude/commands/)
│     Examples: /troubleshoot, /implement, /design
│
├─ An emergency/incident procedure?
│  └─ Runbook (docs/runbooks/)
│     Examples: "How to recover from data loss", "Network policy escape hatch"
│
└─ A quick reference or pattern?
   └─ CLAUDE.md (usually in a domain-specific file)
      Examples: Common commands, short patterns, quick examples
```

---

## Skill File Structure

```
.claude/skills/<skill-name>/
├── SKILL.md              # Main skill definition (REQUIRED)
├── references/           # Supporting documentation (OPTIONAL)
│   ├── patterns.md       # Common patterns and examples
│   └── values-ref.md     # Reference documentation
└── scripts/              # Helper scripts (OPTIONAL)
    ├── check-health.sh   # Executable helpers
    └── validate.sh       # Automation scripts
```

### SKILL.md Structure

Every SKILL.md must have YAML frontmatter followed by the skill content:

```yaml
---
name: skill-name              # Unique identifier (kebab-case)
description: |
  Brief description of what this skill does.

  Use when: (1) Scenario A, (2) Scenario B, (3) Scenario C

  Triggers: "keyword1", "keyword2", "phrase that triggers this skill"
user-invocable: false          # All background skills should set this
---

# Skill Title

[Skill content with workflows, examples, and guidance]
```

### Frontmatter Fields

| Field | Required | Purpose |
|-------|----------|---------|
| `name` | Yes | Unique identifier, matches directory name |
| `description` | Yes | Multi-line description with use cases and triggers |
| `user-invocable` | No | Set to `false` for agent-composed skills (default: `true`) |

---

## When to Create a New Skill

Create when:
1. **Repeated Procedures**: You've explained the same multi-step workflow more than once
2. **Complex Workflows**: The procedure has 5+ steps with decision points
3. **Supporting Resources**: The workflow benefits from reference docs or helper scripts
4. **Domain Expertise**: The task requires specialized knowledge that should be encapsulated

Do NOT create a skill when:
- It's a simple command or pattern (add to CLAUDE.md instead)
- It's a one-off procedure unlikely to be repeated
- The content is purely declarative (what/why, not how)
- A similar skill already exists and could be extended

For creating a new skill, follow the skill-creator skill. Full checklist and deprecation
procedure: see `references/skill-authoring.md`.

---

## Agent-First Architecture

This repository uses an **agent-first** interaction model. Users interact through 3 high-level commands (`/troubleshoot`, `/implement`, `/design`) that dispatch to specialized agents. Skills serve as background knowledge that agents compose internally.

Users interact through `/troubleshoot`, `/implement`, `/design` commands that dispatch to agents. Agents compose skills internally.

Agents are defined in `.claude/agents/`:

| Agent | Role | Model | Mode |
|-------|------|-------|------|
| `troubleshooter` | SRE debugging specialist | inherit | read-only |
| `implementer` | Platform engineer | inherit | full tools |
| `designer` | Principal architect | opus | plan (read-only) |
| `security-tester` | Adversarial red team tester | opus | read-only |

---

## Cross-References

- [Root CLAUDE.md](/CLAUDE.md) - Core principles, anti-patterns, repository structure
- [infrastructure/CLAUDE.md](/infrastructure/CLAUDE.md) - Terragrunt/OpenTofu patterns
- [kubernetes/platform/CLAUDE.md](/kubernetes/platform/CLAUDE.md) - Flux and platform patterns
- [kubernetes/clusters/CLAUDE.md](/kubernetes/clusters/CLAUDE.md) - Cluster configuration
- [.taskfiles/CLAUDE.md](/.taskfiles/CLAUDE.md) - Task runner reference
- [docs/runbooks/](/docs/runbooks/) - Emergency procedures
