# Homelab Infrastructure - Claude Reference

Enterprise-grade bare-metal Kubernetes platform managed declaratively from PXE to production workloads.

# Repository Structure

```
.github/                 # Git related workflows and functionality
.renovate/               # Renovate update automations
.taskfiles/              # Task runner definitions
infrastructure/          # Terragrunt/OpenTofu
kubernetes/
  ├── clusters/          # Per-cluster bootstrap
  └── platform/          # Centralized platform
```

# PRINCIPLES

- Production-grade standards only — no shortcuts; complexity is intentional (learning environment)
- GitOps-driven — Git is the source of truth; if it's not in git, it doesn't exist
- Declarative — no manual operations; no `kubectl apply`, SSH fixes, or UI edits
- Drift is a bug, not an acceptable state
- Reproducible — rebuildable from scratch; all processes must be repeatable and idempotent
- Self-healing — prefer automation and convergence over manual intervention
- Observable — all behavior is measurable
- DRY — single source of truth for all logic; compose abstractions, never copy

# OPERATING RULE

If uncertain:

1. Stop
2. Identify ambiguity
3. Ask the user

**Correctness > speed. Always.**

# SYSTEM MODEL

## Deployment Model

- `main` = desired production state
- Changes flow: PR → merge → artifact → integration → validation → live
- Integration and live are **strict GitOps (Flux-managed)**
- Dev cluster allows controlled experimentation

## Cluster Permissions

| Cluster | Access |
|--------|-------|
| `dev` | Controlled mutation allowed for experimentation |
| `integration` | Read-only |
| `live` | Read-only |

## Guiding Priority

**Always optimize for safety and continuity of the live environment.**

# HARD CONSTRAINTS (NON-NEGOTIABLE)

## Security

- NEVER commit secrets — use external secret systems
- NEVER commit generated artifacts or caches

## Destructive Operations

Require explicit human approval:
- `terragrunt apply` / `tofu apply`
- Resource deletion
- Any irreversible operation

## Git Safety

- No direct commits to `main`
- No force push or history rewriting
- Always use PR workflow
- Use isolated worktrees for changes

## Kubernetes Safety

- No direct changes to integration or live clusters
- Dev cluster is the only place for direct mutation
- Do not use unsafe flags (`--force`, `--grace-period=0`)
- Do not modify CRDs without understanding compatibility

## Declarative Requirement

- No manual steps — ever
- No placeholders requiring follow-up work
- All dependencies must be provisioned via code

**Litmus test:**
After merge, the system must converge with zero human intervention.

## Verification

- Never guess values — verify from source
- Never ignore validation failures
- Never assume intent — ask
