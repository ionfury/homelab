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
- Changes flow: PR → merge → stable OCI artifact → live (direct; canary-checker validates post-deploy)
- Live is the only running cluster and is **strict GitOps (Flux-managed)**
- Dev and integration are offline with no plan to bring them back; there is no staging or experimentation cluster, so changes are validated in CI and by canaries on live

## Cluster Permissions

| Cluster | Access |
|--------|-------|
| `live` | Read-only |
| `dev` | Offline |
| `integration` | Offline |

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

- No direct changes to the live cluster; no cluster currently allows direct mutation
- Do not use unsafe flags (`--force`, `--grace-period=0`)
- Do not modify CRDs without understanding compatibility

## Storage Safety

- NEVER allow Longhorn to be uninstalled by Helm; losing it destroys every volume
- NEVER change StorageClass parameters, and never use Flux force or replace annotations to recreate a StorageClass. Parameters are immutable, recreating a StorageClass is a resource deletion, and existing volumes keep their old values anyway. Per-volume settings belong on the Longhorn `Volume` object
- Irreversible filesystem repairs such as `xfs_repair -L` are human-gated break-glass steps; never automate them

## Upgrade Safety

- Do not set tuppr `policy.waitForVolumeDetach` on the TalosUpgrade. It switches tuppr to its own drain, which never retries, and passes `--drain=false` to talosctl. Talos owns the node drain

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
