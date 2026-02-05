# Stacks - Claude Reference

Terragrunt stacks compose units into deployable infrastructure with specific lifecycles and configurations.

For architecture context (units vs modules), see [infrastructure/CLAUDE.md](../CLAUDE.md). For unit patterns, see [infrastructure/units/CLAUDE.md](../units/CLAUDE.md).

---

## Stack Inventory

| Stack | Lifecycle | Purpose | Units |
|-------|-----------|---------|-------|
| `global` | **Persistent** | Cross-cluster infrastructure (S3 backups, PKI) | longhorn-storage, pki, ingress-pki |
| `dev` | Ephemeral | Development cluster | config, unifi, talos, bootstrap, aws-set-params |
| `integration` | Ephemeral | Integration/validation cluster | config, unifi, talos, bootstrap, aws-set-params |
| `live` | Ephemeral | Production cluster | config, unifi, talos, bootstrap, aws-set-params |

---

## Stack Definition Structure

Each stack has a `terragrunt.stack.hcl` that defines:

1. **Locals**: Stack-specific configuration values
2. **Units**: Which units to include and their values

### Cluster Stack Example (dev)

```hcl
# infrastructure/stacks/dev/terragrunt.stack.hcl
locals {
  name                 = "${basename(get_terragrunt_dir())}"  # "dev"
  features             = ["gateway-api", "longhorn", "prometheus", "spegel"]
  storage_provisioning = "minimal"
}

unit "config" {
  source = "../../units/config"
  path   = "config"

  values = {
    name                 = local.name
    features             = local.features
    storage_provisioning = local.storage_provisioning
  }
}

unit "unifi" {
  source = "../../units/unifi"
  path   = "unifi"
}

# ... additional units
```

### Global Stack Example

```hcl
# infrastructure/stacks/global/terragrunt.stack.hcl
locals {
  clusters = ["dev", "integration", "live"]  # All clusters needing shared infra
}

unit "longhorn_storage" {
  source = "../../units/longhorn-storage"
  path   = "longhorn-storage"

  values = {
    clusters = local.clusters
  }
}

unit "pki" {
  source = "../../units/pki"
  path   = "pki"
}

unit "ingress_pki" {
  source = "../../units/ingress-pki"
  path   = "ingress-pki"
}
```

### Stack Definition Elements

| Element | Purpose |
|---------|---------|
| `locals` | Stack-specific configuration (name, features, etc.) |
| `unit.source` | Path to unit directory in `infrastructure/units/` |
| `unit.path` | Output path in `.terragrunt-stack/` (generated directory) |
| `unit.values` | Data passed to unit's `values.*` references |

---

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

---

## Stack Operations

All operations use task commands — **NEVER** run terragrunt directly.

```bash
# Generate stack files (creates .terragrunt-stack/ directory)
task tg:gen-<stack>            # e.g., task tg:gen-dev

# Validate without applying
task tg:validate-<stack>       # e.g., task tg:validate-dev

# Plan changes
task tg:plan-<stack>           # e.g., task tg:plan-dev

# Apply changes (REQUIRES HUMAN APPROVAL)
task tg:apply-<stack>          # e.g., task tg:apply-dev

# Clean generated files
task tg:clean-<stack>          # e.g., task tg:clean-dev
```

### Stack Generation

`task tg:gen-<stack>` creates the `.terragrunt-stack/` directory with:
- Expanded unit configurations
- Resolved dependencies
- Ready-to-plan infrastructure

**Always regenerate after modifying stack or unit definitions.**

---

## Feature Flags

Stacks enable features via the `features` array:

| Feature | Description | Detection Logic |
|---------|-------------|-----------------|
| `gateway-api` | Gateway API CRDs | `contains(var.features, "gateway-api")` |
| `longhorn` | Distributed storage with iSCSI | `contains(var.features, "longhorn")` |
| `prometheus` | Metrics collection | `contains(var.features, "prometheus")` |
| `spegel` | P2P image distribution | `contains(var.features, "spegel")` |

Feature detection lives in `modules/config/main.tf`:

```hcl
locals {
  gateway_api_enabled = contains(var.features, "gateway-api")
  longhorn_enabled    = contains(var.features, "longhorn")
  prometheus_enabled  = contains(var.features, "prometheus")
  spegel_enabled      = contains(var.features, "spegel")
}
```

---

## Storage Provisioning

Stacks specify storage sizing via `storage_provisioning`:

| Mode | Used By | Prometheus PV | Use Case |
|------|---------|---------------|----------|
| `minimal` | dev, integration | 10Gi | Testing, low resource usage |
| `normal` | live | 50Gi | Production workloads |

Sizing logic is in `modules/config/main.tf` based on provisioning mode.

---

## When to Create a New Stack

```
Need new infrastructure deployment?
│
├─ Is it a new cluster environment?
│   └─ YES → Create new stack in stacks/<name>/
│            Copy from existing cluster stack
│            Adjust features and storage_provisioning
│
├─ Is it persistent cross-cluster infrastructure?
│   └─ YES → Add unit to global stack
│            Do NOT create new stack
│
├─ Is it cluster-specific configuration?
│   └─ YES → Add to config module
│            Do NOT create new stack
│
└─ Is it a new capability for existing clusters?
    └─ YES → Create new unit + module
             Add unit to appropriate stacks
```

### Checklist for New Cluster Stack

1. Create directory: `infrastructure/stacks/<name>/`
2. Create `terragrunt.stack.hcl` (copy from similar stack)
3. Set appropriate `name`, `features`, `storage_provisioning`
4. Add hosts to `inventory.hcl` with `cluster = "<name>"`
5. Add networking config to `networking.hcl`
6. Update `modules/config/main.tf` for cluster-specific logic
7. Run `task tg:gen-<name> && task tg:validate-<name>`

---

## Cross-References

| Document | Focus |
|----------|-------|
| [infrastructure/CLAUDE.md](../CLAUDE.md) | Architecture overview, units vs modules |
| [infrastructure/units/CLAUDE.md](../units/CLAUDE.md) | Unit patterns and dependencies |
| [infrastructure/modules/CLAUDE.md](../modules/CLAUDE.md) | Module development and testing |
| [kubernetes/platform/versions.env](../../kubernetes/platform/versions.env) | Version source of truth |
