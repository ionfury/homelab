# Homelab Infrastructure - Claude Reference

Enterprise-grade bare-metal Kubernetes platform managed declaratively from PXE to production workloads.

---

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

---

# PHILOSOPHY

This system is:

- **Declarative** — no manual operations
- **Reproducible** — rebuildable from scratch
- **GitOps-driven** — Git defines reality
- **Hands-off** — systems self-heal and converge
- **Observable** — all behavior is measurable

---

# OPERATING RULE

If uncertain:

1. Stop
2. Identify ambiguity
3. Ask the user

**Correctness > speed. Always.**

# CORE PRINCIPLES

## Enterprise at Home

- Production-grade standards only — no shortcuts
- Complexity is intentional (learning environment)
- Prefer correctness, resilience, and observability over simplicity

## Everything as Code (GitOps)

- Git is the source of truth — if it’s not in git, it doesn’t exist
- No manual changes (`kubectl apply`, SSH fixes, UI edits are forbidden)
- Drift is a bug, not an acceptable state

## Automation First

- Manual processes are technical debt
- Systems must be repeatable and idempotent
- Prefer self-healing over manual intervention

## DRY and Reuse

- Single source of truth for all logic
- Compose abstractions — do not copy
- Refactor immediately when duplication appears


---

# AGENT BEHAVIOR

**Clarification is mandatory when uncertainty exists.**

## ALWAYS ask when:
- Multiple valid approaches exist
- Requirements are ambiguous or implicit
- A decision impacts architecture or future flexibility
- Something unexpected or inconsistent is encountered
- You are about to guess

## How to ask:
- Present concrete options
- Include trade-offs
- Recommend a preferred option when possible
- Batch related questions

## NEVER:
- Proceed based on assumptions when clarification is possible
- Invent requirements or constraints
- Continue when blocked without asking

---

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

---

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

---

# FAILURE HANDLING PRINCIPLES

## Alerts

- Every alert must be resolved or explicitly silenced declaratively
- Ignored alerts are system failures

## Tests & Validation

- Failures must be investigated and fixed at root cause
- Do not skip or suppress tests without explicit approval
- Fix code, not tests

