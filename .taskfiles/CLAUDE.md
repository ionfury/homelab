# Taskfiles - Claude Reference

Task runner definitions for repository operations, organized by subsystem.

For detailed Taskfile syntax and patterns, invoke the `taskfiles` skill.

---

## Available Task Namespaces

| Namespace | Directory | Purpose |
|-----------|-----------|---------|
| `k8s:` | `kubernetes/` | Kubernetes manifest validation |
| `tg:` | `terragrunt/` | Infrastructure provisioning with OpenTofu |
| `inv:` | `inventory/` | Hardware IPMI management |
| `talos:` | `talos/` | Talos Linux cluster operations |
| `wt:` | `worktree/` | Git worktree-based isolated development |
| `renovate:` | `renovate/` | Dependency update validation |

---

## Quick Reference

### Kubernetes Validation (k8s:)

```bash
task k8s:validate              # Full validation (lint, ResourceSets, charts, kubeconform, deprecations)
task k8s:deprecations          # Show all deprecated APIs (informational - doesn't fail)
task k8s:dry-run-dev           # Server-side dry-run against dev cluster
task k8s:apply-dev             # Apply to dev cluster (with confirmation)
```

### Infrastructure Validation (tg:)

```bash
task tg:fmt                        # Format all HCL files
task tg:test-<module>              # Run tests for specific module
task tg:validate-<stack>           # Validate specific stack
```

### Infrastructure (tg:)

```bash
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

---

## Naming Conventions

| Pattern | Example | Description |
|---------|---------|-------------|
| `namespace:action` | `tg:fmt` | Simple action in namespace |
| `namespace:action-target` | `talos:maint-node41` | Action on specific target |
| `namespace:action-<variable>` | `tg:plan-<stack>` | Dynamic target from variable |

---

## Safe Operation Workflow

For infrastructure changes, always follow this sequence:

1. `task tg:fmt` - Format code
2. `task tg:validate-<stack>` - Validate configuration
3. `task tg:plan-<stack>` - Review planned changes
4. `task tg:apply-<stack>` - Apply (requires human approval)

---

## Dev Cluster Safety

The `dev` cluster is a sandbox environment for testing infrastructure changes. Claude has expanded permissions for dev cluster operations to facilitate testing workflows.

### Allowed Operations (dev cluster only)

```bash
# Status checks (run freely)
task inv:hosts                     # List all hosts
task inv:power-status              # Check power state of all hosts
task inv:status-<host>             # Check specific host IPMI status
task talos:maint                   # Check maintenance mode for all hosts
task talos:maint-<host>            # Check specific host maintenance mode

# Infrastructure operations (require confirmation)
task tg:plan-dev                   # Plan dev cluster changes
task tg:apply-dev                  # Apply dev cluster changes
task tg:gen-dev                    # Generate dev stack
task tg:clean-dev                  # Clean dev stack cache
```

### AWS Credentials

Infrastructure operations require AWS credentials for remote state and Parameter Store access:

```bash
export AWS_PROFILE=terragrunt
export AWS_REGION=us-east-2
```

Verify credentials before running Terragrunt:
```bash
aws sts get-caller-identity
```

### Pre-Flight Checks

Before running infrastructure operations on dev, verify cluster readiness:

1. **Check host power**: `task inv:status-node45` (node45 is the dev cluster host)
2. **Check maintenance mode**: `task talos:maint-node45`

### Confirmation Required

**ALWAYS use AskUserQuestion before:**
- `task tg:apply-dev` (creates/modifies infrastructure)
- Any operation that destroys or recreates resources

This ensures the human operator is aware and approves state-changing operations, even on the dev cluster.

### Scope Boundaries

| Cluster | Claude Permissions |
|---------|-------------------|
| `dev` | Plan, apply, destroy (with confirmation) |
| `integration` | Read-only, validation only |
| `live` | Read-only, validation only |
