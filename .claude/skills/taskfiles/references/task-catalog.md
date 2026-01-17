# Homelab Task Catalog

Complete reference of all tasks available in this repository, organized by namespace.

## Terragrunt Tasks (tg:)

Infrastructure provisioning and validation tasks.

### Validation

| Task | Description |
|------|-------------|
| `task tg:fmt` | Format all HCL files (Terragrunt + OpenTofu) |
| `task tg:test-<module>` | Run OpenTofu native tests for specific module |
| `task tg:validate-<stack>` | Validate Terragrunt stack configuration |

### Infrastructure Operations

| Task | Description |
|------|-------------|
| `task tg:list` | List all available stacks |
| `task tg:gen-<stack>` | Generate stack from units |
| `task tg:plan-<stack>` | Plan infrastructure changes |
| `task tg:apply-<stack>` | Apply changes (REQUIRES HUMAN APPROVAL) |
| `task tg:clean-<stack>` | Clean stack cache and generated files |

### Available Stacks

- `storage` - Persistent backup infrastructure (S3 buckets)
- `dev` - Dev cluster infrastructure
- `integration` - Integration cluster infrastructure
- `live` - Production cluster infrastructure

## Talos Tasks (talos:)

Talos Linux cluster management tasks.

| Task | Description |
|------|-------------|
| `task talos:maint` | Check maintenance mode for all hosts |
| `task talos:maint-<host>` | Check maintenance mode for specific host |

## Inventory Tasks (inv:)

Hardware IPMI management tasks.

### Discovery

| Task | Description |
|------|-------------|
| `task inv:hosts` | List all hosts from inventory |
| `task inv:power-status` | Show power status for all hosts |

### Power Management

| Task | Description |
|------|-------------|
| `task inv:power-on-<host>` | Power on host via IPMI |
| `task inv:power-off-<host>` | Power off host via IPMI |
| `task inv:power-cycle-<host>` | Power cycle host via IPMI |

### Diagnostics

| Task | Description |
|------|-------------|
| `task inv:status-<host>` | Check IPMI status for host |
| `task inv:sol-activate-<host>` | Activate Serial-over-LAN console |

### Available Hosts

From `infrastructure/inventory.hcl`:
- `node41`, `node42`, `node43` - Live cluster (Supermicro x86_64)
- `node44` - Integration cluster (Supermicro x86_64)
- `rpi4`, `node46`, `node47`, `node48` - Dev cluster (mixed ARM64/x86_64)

## Worktree Tasks (wt:)

Git worktree management for isolated development.

| Task | Description |
|------|-------------|
| `task wt:list` | List all worktrees |
| `task wt:new` | Create new worktree for isolated work |
| `task wt:remove` | Remove worktree |
| `task wt:resume` | Resume Claude Code in worktree |

## Renovate Tasks (renovate:)

Dependency update validation.

| Task | Description |
|------|-------------|
| `task renovate:validate` | Validate Renovate configuration |

## Usage Patterns

### Safe Infrastructure Workflow

```bash
# 1. Format code
task tg:fmt

# 2. Validate configuration
task tg:validate-dev

# 3. Review planned changes
task tg:plan-dev

# 4. Apply (requires approval)
task tg:apply-dev
```

### Hardware Debugging

```bash
# Check all hosts
task inv:hosts
task inv:power-status

# Diagnose specific host
task inv:status-node41
task talos:maint-node41

# Console access if needed
task inv:sol-activate-node41
```

### Isolated Development

```bash
# Create isolated worktree
task wt:new

# Work in worktree...

# Resume Claude Code session
task wt:resume

# Clean up when done
task wt:remove
```
