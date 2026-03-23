# Units - Claude Reference

Terragrunt units are thin wiring layers that orchestrate OpenTofu modules. They compose modules into deployable infrastructure without implementing business logic.

For architectural context and the separation of concerns between units and modules, see [infrastructure/CLAUDE.md](../CLAUDE.md).

---

## Unit Inventory

| Unit | Module | Purpose | Dependencies |
|------|--------|---------|--------------|
| `config` | `modules/config` | Computes all cluster configuration; the "brain" of the stack | None |
| `unifi` | `modules/unifi` | Provisions DNS records and DHCP reservations | `config` |
| `talos` | `modules/talos` | Provisions Talos Linux cluster nodes | `config`, `unifi` |
| `bootstrap` | `modules/bootstrap` | Bootstraps Flux GitOps and cluster credentials | `config`, `talos` |
| `aws-set-params` | `modules/aws-set-params` | Stores kubeconfig/talosconfig in AWS SSM | `config`, `talos` |
| `pki` | `modules/pki` | Generates PKI certificates (Istio mesh CA) | None |
| `ingress-pki` | `modules/pki` | Generates PKI certificates (ingress CA) | None |
| `longhorn-storage` | `modules/longhorn-storage` | Provisions S3 backup buckets for all clusters (Longhorn) | None |
| `velero-storage` | `modules/velero-storage` | Provisions S3 backup buckets for all clusters (Velero) | None |

---

## The Config Unit

The `config` unit is the "brain" of every cluster stack. It:

1. **Reads global configuration** from parent HCL files (`inventory.hcl`, `networking.hcl`, `accounts.hcl`)
2. **Reads platform versions** from `kubernetes/platform/versions.env`
3. **Computes cluster-specific configuration** for all other units
4. **Exposes structured outputs** consumed by downstream units

### Config Inputs

```hcl
# infrastructure/units/config/terragrunt.hcl
inputs = {
  name                   = values.name                    # From stack
  features               = values.features                # From stack
  storage_provisioning   = values.storage_provisioning    # From stack
  networking             = local.networking_vars.locals.clusters[values.name]
  machines               = local.inventory_vars.locals.hosts
  versions               = local.versions                 # Parsed from versions.env
  local_paths            = local.local_paths
  accounts               = local.accounts_vars.locals.accounts
  cilium_values_template = file("${get_repo_root()}/kubernetes/platform/charts/cilium.yaml")
}
```

### Config Outputs

Other units consume config outputs via dependency blocks:

| Output | Consumers | Description |
|--------|-----------|-------------|
| `talos` | `talos` unit | Machine configs, versions, bootstrap charts |
| `unifi` | `unifi` unit | DNS records, DHCP reservations |
| `bootstrap` | `bootstrap` unit | Cluster name, flux version, cluster vars, OCI settings |
| `aws_set_params` | `aws-set-params` unit | SSM parameter paths |
| `cluster_name` | Multiple | Cluster identifier |

---

## Unit Structure

Every unit follows this standard pattern:

```hcl
# Include root configuration (remote state, providers)
include "root" {
  path = find_in_parent_folders("root.hcl")
}

# Reference the implementing module
terraform {
  source = "../../../.././/modules/<module-name>"
}

# Declare dependencies on other units
dependency "config" {
  config_path = "../config"

  # Mock outputs enable `terragrunt validate` without applying dependencies
  mock_outputs = {
    # ... structured mock data matching module outputs
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

# Pass dependency outputs to module inputs
inputs = {
  some_input = dependency.config.outputs.module_name.some_output
}
```

### Key Elements

| Element | Purpose |
|---------|---------|
| `include "root"` | Inherits remote state backend, providers, catalog |
| `terraform.source` | Path to implementing module (always relative to repo root) |
| `dependency` | Declares unit ordering and output passing |
| `mock_outputs` | Enables validation without applying dependencies |
| `inputs` | Maps dependency outputs to module variables |

---

## Dependency Patterns

Four patterns exist: Pass-Through, Composed Inputs, Ordering, Mock Outputs. See terragrunt skill references/units.md for HCL examples.

---

## Design Principles

Units must be dumb. Logic lives in modules. Single responsibility. Explicit over implicit. See terragrunt skill references/units.md for BAD/GOOD examples.

---

## When to Add a New Unit

Add a unit only when a new lifecycle boundary is needed. Decision tree in terragrunt skill references/units.md.

---

## Stack Composition

Stacks compose units into deployable infrastructure:

### Cluster Stacks (dev, integration, live)

```hcl
# infrastructure/stacks/dev/terragrunt.stack.hcl
unit "config"        { source = "../../units/config"         }
unit "unifi"         { source = "../../units/unifi"          }
unit "talos"         { source = "../../units/talos"          }
unit "bootstrap"     { source = "../../units/bootstrap"      }
unit "aws_set_params" { source = "../../units/aws-set-params" }
```

### Global Stack

Cross-cluster resources with independent lifecycles:

```hcl
# infrastructure/stacks/global/terragrunt.stack.hcl
unit "longhorn_storage" { source = "../../units/longhorn-storage" }
unit "pki"              { source = "../../units/pki"              }
unit "ingress_pki"      { source = "../../units/ingress-pki"      }
```

---

## Dependency Graph

```
                    +-------------+
                    |   config    |
                    +------+------+
                           |
              +------------+------------+
              v            v            v
        +---------+  +----------+  +-----------------+
        |  unifi  |  |  (other  |  |  aws_set_params |
        +----+----+  |  units)  |  |  (needs talos)  |
             |       +----------+  +--------+--------+
             |                              |
             v                              |
        +---------+                         |
        |  talos  | <-----------------------+
        +----+----+
             |
             v
        +-----------+
        | bootstrap |
        +-----------+
```

**Execution order**: config -> unifi -> talos -> bootstrap, aws-set-params

---

## Cross-References

| Document | Focus |
|----------|-------|
| [infrastructure/CLAUDE.md](../CLAUDE.md) | Architecture overview, testing, stacks |
| [infrastructure/modules/CLAUDE.md](../modules/CLAUDE.md) | Module implementations and testing |
| [kubernetes/platform/versions.env](../../kubernetes/platform/versions.env) | Platform versions (single source of truth) |
