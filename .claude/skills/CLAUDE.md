# Skills Architecture

Skills are procedural guides that provide step-by-step workflows for complex operations. They are lazy-loaded into Claude's context only when relevant to the current task.

---

## Skill Inventory

| Skill | Purpose | User-Invocable | References | Scripts |
|-------|---------|----------------|------------|---------|
| `app-template` | Deploy applications using bjw-s/app-template Helm chart | Yes | patterns.md, values-reference.md | - |
| `deploy-app` | End-to-end application deployment with monitoring integration | Yes | file-templates.md, monitoring-patterns.md | check-alerts.sh, check-canary.sh, check-deployment-health.sh, check-servicemonitor.sh |
| `flux-gitops` | Flux ResourceSet patterns for HelmRelease management | Yes | - | - |
| `k8s-sre` | Kubernetes incident investigation and debugging | Yes | - | cluster-health.sh |
| `kubesearch` | Research Helm configurations from kubesearch.dev | Yes | - | - |
| `loki` | Query Loki API for cluster logs and debugging | Yes | queries.md | logql.sh |
| `opentofu-modules` | OpenTofu module development and testing patterns | Yes | opentofu-testing.md | - |
| `prometheus` | Query Prometheus API for metrics and alerts | Yes | queries.md | promql.sh |
| `self-improvement` | Capture user feedback to enhance documentation | Yes | - | - |
| `sync-claude` | Validate Claude docs against codebase state | Yes | - | discover-claude-docs.sh, extract-references.sh |
| `taskfiles` | Task runner syntax, patterns, and conventions | Yes | schema.md, cli.md, styleguide.md, task-catalog.md | - |
| `terragrunt` | Infrastructure operations with Terragrunt/OpenTofu | Yes | stacks.md, units.md | - |

---

## What is a Skill?

Skills are **procedural knowledge** documents that guide Claude through multi-step workflows. They exist separately from CLAUDE.md files because:

1. **Lazy Loading**: Skills are only loaded when triggered, preserving context window for actual work
2. **Workflow Focus**: Skills describe HOW to do something step-by-step, not what exists or why
3. **Reusable Procedures**: Common operations are codified once and invoked by name
4. **Supporting Resources**: Skills can include reference docs and helper scripts

Skills are invoked when:
- User explicitly calls `/skill-name`
- User's question matches skill triggers (defined in frontmatter)
- Claude determines the skill is relevant to the current task

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

## User-Invocable vs Claude-Only

### Default Behavior (Both)

By default, skills can be invoked by both users (via `/skill-name`) and Claude (when triggers match). This is appropriate for most skills.

### User-Only Skills

Set `disable-model-invocation: true` when:
- The skill should only run on explicit user request
- Claude should not auto-invoke based on triggers
- The procedure is destructive or expensive

Example use case: A "reset-cluster" skill that should never be auto-triggered.

### Claude-Only Skills

Set `user_invocable: false` when:
- The skill is an internal helper not meant for direct use
- The skill is always invoked by another skill
- The procedure requires context Claude has but users don't provide

Example use case: Internal validation or preprocessing skills.

### Summary

| Configuration | User /command | Claude Auto-Invoke |
|---------------|---------------|-------------------|
| Default | Yes | Yes |
| `disable-model-invocation: true` | Yes | No |
| `user_invocable: false` | No | Yes |

---

## Cross-References

- [Root CLAUDE.md](/CLAUDE.md) - Core principles, anti-patterns, repository structure
- [infrastructure/CLAUDE.md](/infrastructure/CLAUDE.md) - Terragrunt/OpenTofu patterns
- [kubernetes/platform/CLAUDE.md](/kubernetes/platform/CLAUDE.md) - Flux and platform patterns
- [kubernetes/clusters/CLAUDE.md](/kubernetes/clusters/CLAUDE.md) - Cluster configuration
- [.taskfiles/CLAUDE.md](/.taskfiles/CLAUDE.md) - Task runner reference
- [docs/runbooks/](/docs/runbooks/) - Emergency procedures
