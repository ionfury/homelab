# Skills Architecture

Skills are procedural guides that provide step-by-step workflows for complex operations. They are lazy-loaded into Claude's context only when relevant to the current task.

---

## Skill Inventory

### Agent Dispatch Skills

These skills serve as slash command entry points that delegate to specialized agents. Users interact with agents through these commands.

| Skill | Dispatches To | Purpose |
|-------|--------------|---------|
| `troubleshoot` | `troubleshooter` agent | Kubernetes and infrastructure debugging |
| `implement` | `implementer` agent | Deploy apps, write IaC, create PRs |
| `design` | `designer` agent | Architecture design and review |

### Background Skills (Agent-Composed)

These skills are composed by agents internally. They are not invoked directly by users — agents load them as needed for domain-specific knowledge.

| Skill | Purpose | Composed By | References | Scripts |
|-------|---------|-------------|------------|---------|
| `app-template` | Deploy applications using bjw-s/app-template Helm chart | implementer | patterns.md, values-reference.md | - |
| `architecture-review` | Architecture evaluation criteria and technology standards | designer | technology-decisions.md | - |
| `cnpg-database` | CNPG PostgreSQL cluster provisioning and credential management | implementer | - | - |
| `deploy-app` | End-to-end application deployment with monitoring integration | implementer | file-templates.md, monitoring-patterns.md | check-alerts.sh, check-canary.sh, check-deployment-health.sh, check-servicemonitor.sh |
| `flux-gitops` | Flux ResourceSet patterns for HelmRelease management | implementer | - | - |
| `gateway-routing` | Gateway API routing, TLS certificates, and WAF configuration | implementer | - | - |
| `k8s` | Kubernetes cluster access, kubectl, and Flux operations | troubleshooter, implementer | - | - |
| `kubesearch` | Research Helm configurations from kubesearch.dev | designer | - | - |
| `loki` | Query Loki API for cluster logs and debugging | troubleshooter | queries.md | logql.sh |
| `monitoring-authoring` | Author PrometheusRules, ServiceMonitors, AlertmanagerConfig, canary checks | implementer | - | - |
| `opentofu-modules` | OpenTofu module development and testing patterns | implementer | opentofu-testing.md | - |
| `prometheus` | Query Prometheus API for metrics and alerts | troubleshooter | queries.md | promql.sh |
| `promotion-pipeline` | OCI artifact promotion pipeline tracing and rollback | troubleshooter | - | - |
| `secrets` | Secret provisioning: secret-generator, ExternalSecret, app-secrets | implementer | - | - |
| `self-improvement` | Capture user feedback to enhance documentation | orchestrator | - | - |
| `sre` | Kubernetes incident investigation and debugging | troubleshooter | - | cluster-health.sh |
| `sync-claude` | Validate Claude docs against codebase state | orchestrator | - | discover-claude-docs.sh, extract-references.sh |
| `taskfiles` | Task runner syntax, patterns, and conventions | implementer | schema.md, cli.md, styleguide.md, task-catalog.md | - |
| `terragrunt` | Infrastructure operations with Terragrunt/OpenTofu | implementer | stacks.md, units.md | - |
| `versions-renovate` | Version management and Renovate annotation configuration | implementer | - | - |

---

## What is a Skill?

Skills are **procedural knowledge** documents that guide Claude through multi-step workflows. They exist separately from CLAUDE.md files because:

1. **Lazy Loading**: Skills are only loaded when triggered, preserving context window for actual work
2. **Workflow Focus**: Skills describe HOW to do something step-by-step, not what exists or why
3. **Reusable Procedures**: Common operations are codified once and invoked by name
4. **Supporting Resources**: Skills can include reference docs and helper scripts

Skills are invoked when:
- An agent composes the skill as part of its domain knowledge
- Claude determines the skill is relevant to the current task
- A dispatch skill delegates to the corresponding agent (e.g., `/troubleshoot` → troubleshooter agent)

---

## Skill vs CLAUDE.md Boundary

| Type | Purpose | Content |
|------|---------|---------|
| **CLAUDE.md** | Declarative knowledge | What exists, why it exists, constraints, patterns, anti-patterns |
| **Skills** | Procedural knowledge | Step-by-step how-to workflows, decision trees, execution guides |
| **Runbooks** | Emergency procedures | Incident response, disaster recovery, manual overrides |

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
---

# Skill Title

[Skill content with workflows, examples, and guidance]
```

### Frontmatter Fields

| Field | Required | Purpose |
|-------|----------|---------|
| `name` | Yes | Unique identifier, matches directory name |
| `description` | Yes | Multi-line description with use cases and triggers |
| `user_invocable` | No | Set to `false` to make Claude-only (default: `true`) |
| `disable-model-invocation` | No | Set to `true` to make user-only |

---

## When to Create a New Skill

Create a new skill when:

1. **Repeated Procedures**: You've explained the same multi-step workflow more than once
2. **Complex Workflows**: The procedure has 5+ steps with decision points
3. **Supporting Resources**: The workflow benefits from reference docs or helper scripts
4. **Domain Expertise**: The task requires specialized knowledge that should be encapsulated

Do NOT create a skill when:
- It's a simple command or pattern (add to CLAUDE.md instead)
- It's a one-off procedure unlikely to be repeated
- The content is purely declarative (what/why, not how)

### Creating a New Skill

1. Create directory: `.claude/skills/<skill-name>/`
2. Create `SKILL.md` with proper frontmatter
3. Add references/ if supporting docs are needed
4. Add scripts/ if automation helpers are useful
5. Update root CLAUDE.md skills table if appropriate

---

## Skill Maintenance

### When to Update Skills

- When underlying systems change (API updates, new versions)
- When users report confusion or errors following procedures
- When better patterns are discovered
- When referenced paths, commands, or tools change

### Validation

Skills should be validated with the `sync-claude` skill, which checks:
- File/directory paths mentioned exist
- Commands referenced are valid
- Cross-references to other docs are accurate

### Deprecation

To deprecate a skill:
1. Add notice at top of SKILL.md: `**DEPRECATED**: Use [new-skill] instead`
2. Keep for one release cycle to allow transition
3. Remove directory after transition period

---

## Agent-First Architecture

This repository uses an **agent-first** interaction model. Users interact through 3 high-level commands (`/troubleshoot`, `/implement`, `/design`) that dispatch to specialized agents. Skills serve as background knowledge that agents compose internally.

### How It Works

```
User → /troubleshoot → dispatch skill → troubleshooter agent → composes: sre, k8s, loki, prometheus
User → /implement    → dispatch skill → implementer agent    → composes: flux-gitops, app-template, terragrunt, ...
User → /design       → dispatch skill → designer agent       → composes: kubesearch, architecture-review
```

### Skill Invocability

| Configuration | User /command | Agent Composition | Use Case |
|---------------|---------------|-------------------|----------|
| Dispatch skill (`disable-model-invocation: true`) | Yes | No | Entry points: troubleshoot, implement, design |
| Background skill (`user_invocable: false`) | No | Yes | Domain knowledge composed by agents |

### Agents

Agents are defined in `.claude/agents/` and compose skills for their domain:

| Agent | Role | Skills | Model | Mode |
|-------|------|--------|-------|------|
| `troubleshooter` | SRE debugging specialist | sre, k8s, loki, prometheus, promotion-pipeline | inherit | default (read-only tools) |
| `implementer` | Platform engineer | flux-gitops, app-template, terragrunt, opentofu-modules, deploy-app, taskfiles, k8s, secrets, monitoring-authoring, cnpg-database, gateway-routing, versions-renovate | inherit | default (full tools) |
| `designer` | Principal architect | kubesearch, architecture-review | opus | plan (read-only) |

---

## Cross-References

- [Root CLAUDE.md](/CLAUDE.md) - Core principles, anti-patterns, repository structure
- [infrastructure/CLAUDE.md](/infrastructure/CLAUDE.md) - Terragrunt/OpenTofu patterns
- [kubernetes/platform/CLAUDE.md](/kubernetes/platform/CLAUDE.md) - Flux and platform patterns
- [kubernetes/clusters/CLAUDE.md](/kubernetes/clusters/CLAUDE.md) - Cluster configuration
- [.taskfiles/CLAUDE.md](/.taskfiles/CLAUDE.md) - Task runner reference
- [docs/runbooks/](/docs/runbooks/) - Emergency procedures
