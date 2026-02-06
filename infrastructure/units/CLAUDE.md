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
| `longhorn-storage` | `modules/longhorn-storage` | Provisions S3 backup buckets for all clusters | None |

---

## Architecture Context

Units follow a strict separation of concerns:

### Units = Thin Wiring

Units wire dependencies between modules and pass configuration through. They contain:
- Module source references
- Dependency declarations
- Input mappings from dependencies to module variables
- **No business logic, no conditionals, no computations**

### Modules = Implementation

Modules contain all business logic:
- Conditional expressions based on cluster name
- Feature flag handling
- Resource provisioning
- Data transformations

### Why This Pattern?

1. **Testability**: Module logic is tested via `tofu test`; units are too simple to need tests
2. **Single source of truth**: All environment differences live in the config module
3. **Maintainability**: Adding a new cluster only requires updating the config module
4. **Visibility**: Easy to audit what differs between environments

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

### Simple Pass-Through

When a module's inputs match a config output exactly:

```hcl
# infrastructure/units/talos/terragrunt.hcl
inputs = dependency.config.outputs.talos
```

### Composed Inputs

When inputs come from multiple sources:

```hcl
# infrastructure/units/bootstrap/terragrunt.hcl
inputs = {
  # From config output
  cluster_name     = dependency.config.outputs.bootstrap.cluster_name
  flux_version     = dependency.config.outputs.bootstrap.flux_version

  # From talos output (kubeconfig for cluster access)
  kubeconfig = {
    host                   = dependency.talos.outputs.kubeconfig_host
    client_certificate     = dependency.talos.outputs.kubeconfig_client_certificate
    client_key             = dependency.talos.outputs.kubeconfig_client_key
    cluster_ca_certificate = dependency.talos.outputs.kubeconfig_cluster_ca_certificate
  }

  # From parent HCL files
  github = local.accounts_vars.locals.accounts.github
}
```

### Ordering Dependencies

Use `skip_outputs = true` when you need ordering but no outputs:

```hcl
# infrastructure/units/talos/terragrunt.hcl
dependency "unifi" {
  config_path = "../unifi"

  mock_outputs                            = {}
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
  skip_outputs                            = true  # Only for ordering
}
```

### Mock Outputs

Mock outputs enable `terragrunt validate` and `terragrunt plan` without applying dependencies. They must match the structure of real outputs:

```hcl
mock_outputs = {
  talos = {
    talos_version      = "v1.12.0"
    kubernetes_version = "1.34.0"
    talos_machines = [
      {
        install = { selector = "disk.model = *", secureboot = false }
        configs = ["kind: HostnameConfig\nhostname: mock"]
      }
    ]
  }
}
mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
```

---

## Design Principles

### Keep Units Dumb

Units should contain **zero business logic**:

```hcl
# BAD - logic in unit
inputs = {
  replica_count = length(dependency.config.outputs.machines) > 3 ? 3 : length(...)
}

# GOOD - logic in module
inputs = dependency.config.outputs.bootstrap
# The config module computes replica_count internally
```

### Delegate to Modules

All conditional logic, feature flags, and environment differences belong in modules:

```hcl
# infrastructure/modules/config/main.tf
locals {
  oci_config = {
    dev         = { source_type = "git", semver = "" }
    integration = { source_type = "oci", semver = ">= 0.0.0-0" }
    live        = { source_type = "oci", semver = ">= 0.0.0" }
  }
}
```

### Single Responsibility

Each unit orchestrates exactly one module:

| Unit | Module | Single Responsibility |
|------|--------|----------------------|
| `config` | `config` | Compute configuration |
| `talos` | `talos` | Provision Talos nodes |
| `bootstrap` | `bootstrap` | Bootstrap Flux |
| `pki` | `pki` | Generate certificates |

### Reuse Modules

Multiple units can use the same module with different inputs:

```hcl
# infrastructure/units/pki/terragrunt.hcl
inputs = {
  ca_name = "istio-mesh"
  ca_subject = { organization = "homelab", common_name = "istio-mesh-root-ca" }
}

# infrastructure/units/ingress-pki/terragrunt.hcl (same module, different config)
inputs = {
  ca_name = "homelab-ingress"
  ca_subject = { organization = "homelab", common_name = "homelab-ingress-root-ca" }
}
```

---

## When to Add a New Unit

Use this decision tree:

```
Need new infrastructure capability?
|
+- Is it a new instance of existing module?
|   +- YES -> Create new unit referencing existing module
|            Example: ingress-pki reuses pki module
|
+- Is it a new capability entirely?
|   +- YES -> Create new module first, then new unit
|            1. Add module to infrastructure/modules/
|            2. Add unit to infrastructure/units/
|            3. Include unit in relevant stacks
|
+- Is it cluster-specific configuration?
|   +- YES -> Add to config module outputs
|            Do NOT create new unit
|
+- Is it a transformation of existing data?
    +- YES -> Add logic to config module
             Do NOT create new unit
```

### Checklist for New Units

1. Create module in `infrastructure/modules/<name>/`
2. Write tests in `infrastructure/modules/<name>/tests/`
3. Create unit in `infrastructure/units/<name>/terragrunt.hcl`
4. Add unit to relevant stacks in `infrastructure/stacks/*/terragrunt.stack.hcl`
5. Run `task tg:fmt && task tg:test-<name> && task tg:validate-<stack>`

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
