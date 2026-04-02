# Taskfiles - Claude Reference

Task runner definitions for repository operations, organized by subsystem.

For detailed Taskfile syntax and patterns, invoke the `taskfiles` skill.

## Available Task Namespaces

| Namespace | Directory | Purpose |
|-----------|-----------|---------|
| `k8s:` | `kubernetes/` | Kubernetes manifest validation |
| `tg:` | `terragrunt/` | Infrastructure provisioning with OpenTofu |
| `inv:` | `inventory/` | Hardware IPMI management |
| `talos:` | `talos/` | Talos Linux cluster operations |
| `wt:` | `worktree/` | Git worktree-based isolated development |
| `renovate:` | `renovate/` | Dependency update validation |

## Quick Reference

### Kubernetes Validation & Dev Workflow (k8s:)

```bash
# Kubeconfig setup (run once after credentials refresh)
task k8s:kubeconfig-sync       # Pull kubeconfigs from AWS SSM, merge to ~/.kube/config with dev/integration/live contexts

# Validation
task k8s:validate              # Full validation (lint, ResourceSets, charts, kubeconform, deprecations)
task k8s:deprecations          # Show all deprecated APIs (informational - doesn't fail)

# Dev cluster operations (autonomous)
task k8s:dry-run-dev           # Server-side dry-run against dev cluster
task k8s:apply-dev             # Apply expanded ResourceSets to dev cluster
task k8s:flux-suspend -- <ks>  # Suspend a Flux Kustomization on dev
task k8s:flux-resume -- <ks>   # Resume a Flux Kustomization on dev
task k8s:flux-status           # Show Flux Kustomization status on dev
task k8s:reconcile-validate    # Resume all Flux, reconcile, validate clean state
```

### Infrastructure (tg:)

```bash
task tg:fmt                        # Format all HCL files
task tg:test-<module>              # Run tests for specific module
task tg:validate-<stack>           # Validate specific stack
task tg:list                       # List all stacks
task tg:gen-<stack>                # Generate stack from units
task tg:plan-<stack>               # Plan changes
task tg:apply-<stack>              # Apply (REQUIRES HUMAN APPROVAL)
task tg:clean-<stack>              # Clean stack cache
```

### Talos (talos:)

```bash
task talos:maint                   # Check maintenance mode for all hosts
task talos:maint-<host>            # Check maintenance mode for specific host
```

### Hardware/IPMI (inv:)

```bash
task inv:hosts                     # List all hosts
task inv:power-status              # Power status for all hosts
task inv:power-on-<host>           # Power on via IPMI
task inv:power-off-<host>          # Power off via IPMI
task inv:power-cycle-<host>        # Power cycle via IPMI
task inv:status-<host>             # Check IPMI status
task inv:sol-activate-<host>       # Serial-over-LAN console
```

### Worktrees (wt:)

```bash
task wt:list                       # List all worktrees
task wt:new                        # Create worktree for isolated work
task wt:remove                     # Remove worktree
task wt:resume                     # Resume Claude Code in worktree
```

### Renovate (renovate:)

```bash
task renovate:validate             # Validate Renovate config
```

## Naming Conventions

| Pattern | Example | Description |
|---------|---------|-------------|
| `namespace:action` | `tg:fmt` | Simple action in namespace |
| `namespace:action-target` | `talos:maint-node41` | Action on specific target |
| `namespace:action-<variable>` | `tg:plan-<stack>` | Dynamic target from variable |

## Dev Cluster Operations

The `dev` cluster is a **sandbox for rapid iteration**. Claude operates autonomously on dev — applying, debugging, and mutating directly. Integration and live remain strictly read-only.

Dev sandbox workflow: Suspend Kustomization → Experiment on dev → Write/refine manifests → Resume Flux → Validate convergence → Open PR

### Key Principles

- **Same manifest format**: Always write changes as proper manifests/values files — never use ad-hoc `kubectl edit` or `kubectl patch` as a substitute for writing the actual files
- **Suspend, don't disable**: Use `task k8s:flux-suspend` for targeted Kustomization suspension rather than disabling Flux entirely
- **Reconcile before PR**: Always run `task k8s:reconcile-validate` before opening a PR to prove manifests work through the GitOps path
- **Destroy as last resort**: If the cluster is too dirty to reconcile, `task tg:apply-dev` can rebuild it (~10 min). This is a smell, not the happy path

### AWS Credentials

Infrastructure operations require AWS credentials: set `AWS_PROFILE=terragrunt` and `AWS_REGION=us-east-2`. Verify with `aws sts get-caller-identity` before running Terragrunt. Check host readiness with `task inv:status-node45` and `task talos:maint-node45` before infrastructure operations on dev.

### Confirmation Required

**ALWAYS confirm before:**
- `task tg:apply-dev` (creates/modifies infrastructure)
- Any operation that destroys or recreates the cluster

Kubernetes-level operations (`kubectl apply`, `helm install`, Flux suspend/resume) are **autonomous** on dev and do not require confirmation.

### Scope Boundaries

| Cluster | Claude Permissions |
|---------|-------------------|
| `dev` | **Autonomous**: kubectl apply/delete, helm install/uninstall, Flux suspend/resume. **With confirmation**: tg:apply-dev, cluster destroy/recreate |
| `integration` | Read-only, validation only |
| `live` | Read-only, validation only |
