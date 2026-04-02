# Stacks - Claude Reference

Terragrunt stacks compose units into deployable infrastructure with specific lifecycles and configurations.

For architecture context (units vs modules), see [infrastructure/CLAUDE.md](../CLAUDE.md). For unit patterns, see [infrastructure/units/CLAUDE.md](../units/CLAUDE.md).

## Stack Inventory

| Stack | Lifecycle | Purpose | Units |
|-------|-----------|---------|-------|
| `global` | **Persistent** | Cross-cluster infrastructure (S3 backups, PKI) | longhorn-storage, velero-storage, pki, ingress-pki |
| `dev` | Ephemeral | Development cluster | config, unifi, talos, bootstrap, aws-set-params |
| `integration` | Ephemeral | Integration/validation cluster | config, unifi, talos, bootstrap, aws-set-params |
| `live` | Ephemeral | Production cluster | config, unifi, talos, bootstrap, aws-set-params |

## Stack Definition Structure

Each stack has a `terragrunt.stack.hcl` that defines locals (stack-specific config values) and units (which units to include and their values).

### Stack Definition Elements

| Element | Purpose |
|---------|---------|
| `locals` | Stack-specific configuration (name, features, etc.) |
| `unit.source` | Path to unit directory in `infrastructure/units/` |
| `unit.path` | Output path in `.terragrunt-stack/` (generated directory) |
| `unit.values` | Data passed to unit's `values.*` references |

## Lifecycle Types

### Persistent Stacks

**Global stack is persistent** — it contains resources that must survive cluster rebuilds:

- **S3 backup buckets** for Longhorn disaster recovery
- **PKI certificates** for Istio mesh and ingress
- **IAM credentials** for cluster access to backups

**Operational rules:**
- ❌ **NEVER** destroy without explicit approval and backup verification
- ❌ **NEVER** include in routine stack refreshes
- ✅ Apply changes carefully with thorough review

### Ephemeral Stacks

**Cluster stacks (dev, integration, live) are ephemeral** — they can be rebuilt from git:

- Talos machine configurations
- Kubernetes bootstrap resources
- Network provisioning (DNS, DHCP)

**Operational rules:**
- ✅ Can be destroyed and recreated
- ✅ Safe to rebuild from scratch
- ✅ State stored in S3 for recovery

## Stack Operations

> For Terragrunt operations, invoke the `terragrunt` skill.

All operations use task commands — **NEVER** run terragrunt directly. See `.taskfiles/CLAUDE.md` for full command reference.

**Always regenerate after modifying stack or unit definitions** (`task tg:gen-<stack>`).

## Feature Flags

Stacks enable features via the `features` array passed to the config unit:

| Feature | Description |
|---------|-------------|
| `gateway-api` | Gateway API CRDs |
| `longhorn` | Distributed storage with iSCSI |
| `prometheus` | Metrics collection |
| `spegel` | P2P image distribution |

Feature detection logic lives in `modules/config/main.tf`.

## Storage Provisioning

Stacks specify storage sizing via `storage_provisioning`:

| Mode | Used By | Prometheus PV | Use Case |
|------|---------|---------------|----------|
| `minimal` | dev, integration | 10Gi | Testing, low resource usage |
| `normal` | live | 50Gi | Production workloads |

## When to Create a New Stack

- New cluster environment → create new stack in `stacks/<name>/`, copy from existing cluster stack
- Persistent cross-cluster infrastructure → add unit to global stack, do NOT create new stack
- Cluster-specific configuration → add to config module, do NOT create new stack
- New capability for existing clusters → create new unit + module, add to appropriate stacks

### Checklist for New Cluster Stack

1. Create directory: `infrastructure/stacks/<name>/`
2. Create `terragrunt.stack.hcl` (copy from similar stack)
3. Set appropriate `name`, `features`, `storage_provisioning`
4. Add hosts to `inventory.hcl` with `cluster = "<name>"`
5. Add networking config to `networking.hcl`
6. Update `modules/config/main.tf` for cluster-specific logic
7. Run `task tg:gen-<name> && task tg:validate-<name>`
