# Documentation - Claude Reference

The `docs/` directory contains operational runbooks, architectural plans, and supporting assets.

---

## Directory Structure

```
docs/
├── runbooks/           # Emergency and operational procedures
├── plans/              # Architectural design documents
│   └── .archive/       # Superseded plans
└── images/             # Supporting images and diagrams
```

---

## Runbook Inventory

| Runbook | Trigger Condition | Est. Time | Related Docs |
|---------|-------------------|-----------|--------------|
| `longhorn-disaster-recovery.md` | Complete cluster loss, need S3 restore | ~30 min | infrastructure/CLAUDE.md |
| `network-policy-escape-hatch.md` | Emergency - network policies blocking critical traffic | ~5 min | kubernetes/platform/CLAUDE.md |
| `network-policy-verification.md` | Verify network policy enforcement with Hubble | ~10 min | kubernetes/platform/CLAUDE.md |
| `resize-volume.md` | Longhorn auto-expansion fails, PVC at capacity | ~5 min | kubernetes/platform/CLAUDE.md |
| `supermicro-machine-setup.md` | New hardware - initial BIOS/IPMI config | ~20 min | infrastructure/CLAUDE.md |
| `terragrunt-validation-state-issues.md` | Terragrunt validate fails with partial state | ~10 min | infrastructure/CLAUDE.md |

### Runbook Summaries

**longhorn-disaster-recovery.md**
Complete cluster recovery procedure: rebuild infrastructure from git, restore Longhorn volumes from S3 backups. Use when cluster is unrecoverable.

**network-policy-escape-hatch.md**
Emergency bypass for network policies when they're blocking critical traffic. Temporary measure - must be reverted after debugging.

**network-policy-verification.md**
Verify Cilium network policies are working using Hubble flow observation. Use after policy changes or suspected policy issues.

**resize-volume.md**
Manual PVC resize when Longhorn's automatic expansion fails. Involves patching PVC and triggering filesystem resize.

**supermicro-machine-setup.md**
Physical setup checklist for new Supermicro hardware: BIOS settings, IPMI configuration, boot order for PXE.

**terragrunt-validation-state-issues.md**
Resolve "partial state" errors during `terragrunt validate`. Usually caused by missing dependencies or stale cache.

---

## Plan Documents

| Plan | Status | Purpose |
|------|--------|---------|
| `coraza-waf.md` | Implemented | Coraza WAF integration for ingress protection |
| `longhorn-dr-exercise.md` | In Progress | Automated disaster recovery exercise design |
| `network-policy-architecture.md` | Implemented | Two-tier network policy model (namespace + workload) |
| `oci-artifact-promotion.md` | In Progress | OCI-based GitOps promotion pipeline |

**Archived plans** (in `docs/plans/.archive/`) are superseded designs kept for historical reference.

---

## Runbook vs CLAUDE.md vs Skill

Use this decision tree to determine where documentation belongs:

```
Is this knowledge...

├─ An emergency/incident procedure?
│  └─ RUNBOOK (docs/runbooks/)
│     - Step-by-step recovery actions
│     - Time-sensitive operations
│     - Procedures with potential data loss risk
│     Examples: Disaster recovery, emergency policy bypass
│
├─ Declarative knowledge about the system?
│  └─ CLAUDE.md (appropriate directory)
│     - How the system works
│     - Architecture and design decisions
│     - Constraints and anti-patterns
│     Examples: ResourceSet patterns, testing philosophy
│
├─ A multi-step workflow for normal operations?
│  └─ SKILL (.claude/skills/)
│     - Procedural how-to guides
│     - Repeatable development workflows
│     - Task automation guidance
│     Examples: Adding a Helm release, debugging Flux
│
└─ An architectural design or proposal?
    └─ PLAN (docs/plans/)
       - Design documents
       - Implementation proposals
       - Architectural decisions
       Examples: Network policy architecture, promotion pipeline
```

---

## Runbook Format Guidelines

### Template Structure

```markdown
# Runbook: <Title>

## Overview
Brief description of what this runbook addresses.

## Prerequisites
- Required access/permissions
- Required tools
- Required knowledge

## Procedure

### Step 1: <Action>
Specific commands and explanations.

### Step 2: <Action>
...

## Verification
How to confirm the procedure succeeded.

## Rollback (if applicable)
How to undo changes if something goes wrong.

## Related
Links to related runbooks, CLAUDE.md sections, or skills.
```

### Style Guidelines

- **Be explicit**: Include exact commands, not just descriptions
- **Warn about risks**: Call out destructive operations clearly
- **Include verification**: Every procedure should end with "how to confirm success"
- **Time estimates**: Include realistic time estimates for planning
- **Prerequisites first**: List what's needed before starting

---

## Naming Conventions

### Runbooks

Pattern: `<topic>-<action>.md` (kebab-case)

| Good | Bad |
|------|-----|
| `resize-volume.md` | `ResizeVolume.md` |
| `longhorn-disaster-recovery.md` | `dr.md` |
| `network-policy-escape-hatch.md` | `net-pol-fix.md` |

### Plans

Pattern: `<feature-or-system>.md` (kebab-case)

| Good | Bad |
|------|-----|
| `network-policy-architecture.md` | `netpol.md` |
| `oci-artifact-promotion.md` | `promotion.md` |

---

## Adding a New Runbook

### When to Create a Runbook

- Procedure involves **risk of data loss** or service disruption
- Procedure is **time-sensitive** (incident response)
- Procedure requires **specific sequence** of steps
- Procedure is **rarely performed** but critical when needed

### Process

1. Create file: `docs/runbooks/<topic>-<action>.md`
2. Follow the template structure above
3. Include realistic time estimates
4. Add verification steps
5. Add to root CLAUDE.md runbooks table if appropriate
6. Test the procedure if possible

### Checklist

- [ ] Clear title describing the scenario
- [ ] Prerequisites listed
- [ ] Step-by-step commands (not just descriptions)
- [ ] Verification steps included
- [ ] Rollback procedure (if applicable)
- [ ] Time estimate in root CLAUDE.md table

---

## Cross-References

| Document | Focus |
|----------|-------|
| [Root CLAUDE.md](../CLAUDE.md) | Core principles, runbooks table |
| [infrastructure/CLAUDE.md](../infrastructure/CLAUDE.md) | Infrastructure patterns |
| [kubernetes/platform/CLAUDE.md](../kubernetes/platform/CLAUDE.md) | Platform configuration |
| [.claude/skills/CLAUDE.md](../.claude/skills/CLAUDE.md) | Skill architecture |

### Related Skills

| Skill | Use For |
|-------|---------|
| `k8s-sre` | Kubernetes debugging (before escalating to runbook) |
| `terragrunt` | Infrastructure operations |
| `flux-gitops` | GitOps debugging |
