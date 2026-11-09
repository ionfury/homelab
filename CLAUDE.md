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

# ARCHITECTURE DECISION RECORDS

Architectural decisions live in `docs/adr/`, in Matt Pocock's ADR format (`mattpocock/skills`, `skills/engineering/domain-modeling/ADR-FORMAT.md`).

- Read the relevant ADRs before changing anything they cover. Never reverse a recorded decision silently: raise it with the user, and if they agree, write a new ADR and set the old one's Status frontmatter to `superseded by ADR-NNNN`.
- Offer an ADR only when the decision is architectural (system shape, integration patterns, technology choices with lock-in, boundaries, deliberate deviations from the obvious design) and all three are true:
  1. Hard to reverse
  2. Surprising without context
  3. The result of a real trade-off
- Settings, guardrails and process decisions are not ADRs. Their reasoning belongs in the commit body; run `git log -S'<setting>'` and read the bodies before changing a setting. Hard rules belong in this file.
- Format: `docs/adr/NNNN-slug.md`, numbered one above the highest existing file. A title plus 1-3 sentences: context, decision, why. Optional sections only when they add real value: Status frontmatter, Considered Options, Consequences.
- ADRs record decisions only. No TODOs, tech debt or follow-up notes.

# SYSTEM MODEL

## Deployment Model

- `main` = desired production state
- Changes flow: PR → merge → stable OCI artifact → live (direct; canary-checker validates post-deploy)
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

## Container Images

- NEVER use linuxserver.io images (`lscr.io/linuxserver/*`) — ever, for any app
- Use official upstream images or distroless alternatives instead
- ALWAYS pin the latest stable release when first adding an image — never guess a tag from training data. Verify the newest tag from the source registry (e.g. `curl` the GHCR/Docker Hub tags list, `skopeo list-tags`, or the upstream GitHub releases/tags) and use it. Prefer a specific semver tag over `latest`; avoid pre-release/`beta`/`rc` tags unless explicitly requested.

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
- After creating a worktree branch, immediately run `git push -u origin <branch>` to establish remote tracking — this enables `fetch --prune` to detect merged branches and keeps local state clean

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
