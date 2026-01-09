# Infrastructure - Terragrunt/OpenTofu Reference

This directory provisions bare-metal infrastructure from PXE boot to running Kubernetes clusters using Terragrunt and OpenTofu.

---

# ARCHITECTURE

## Units vs Stacks

**Units** (`units/`) are reusable, composable Terraform modules wrapped by Terragrunt:
- Each unit does ONE thing (config, talos, bootstrap, unifi, aws-set-params)
- Units declare explicit dependencies on other units via `dependency` blocks
- Units NEVER contain cluster-specific values - they receive them from stacks via `values`

**Stacks** (`stacks/`) orchestrate units into complete cluster deployments:
- One stack per cluster environment (dev, integration)
- Stacks pass values to units via `values = { }` blocks
- Stack files are named `terragrunt.stack.hcl` (not `.hcl`)

```hcl
# CORRECT: Stack passes values, unit consumes them
unit "config" {
  source = "../../units/config"
  path   = "config"
  values = {
    name     = local.name      # Cluster name from stack
    features = local.features  # Feature flags from stack
  }
}
```

**Modules** (`modules/`) contain the actual Terraform code:
- Pure Terraform, no Terragrunt-specific code
- Receives inputs from units via `inputs = { }`
- Outputs consumed by dependent units via `dependency.*.outputs`

## Directory Structure

```
infrastructure/
├── stacks/              # Cluster deployments
│   ├── dev/             # terragrunt.stack.hcl
│   └── integration/     # terragrunt.stack.hcl
├── units/               # Reusable Terragrunt units
│   ├── config/          # Configuration generator (the brain)
│   ├── talos/           # Talos cluster provisioning
│   ├── bootstrap/       # Flux GitOps bootstrap
│   ├── unifi/           # Network configuration
│   └── aws-set-params/  # AWS SSM parameter storage
├── modules/             # Terraform modules
│   └── (mirrors units structure)
├── inventory.hcl        # Hardware inventory
├── networking.hcl       # Network topology
├── versions.hcl         # Pinned versions
├── accounts.hcl         # External service credentials
└── root.hcl             # Terragrunt root config
```

## Dependency Chain

Units execute in this order (enforced by `dependency` blocks):

```
config ──┬── unifi
         │
         └── talos ──┬── bootstrap
                     │
                     └── aws-set-params
```

**The `config` unit is the brain.** It:
1. Reads inventory.hcl, networking.hcl, versions.hcl, accounts.hcl
2. Filters and transforms data for the specific cluster
3. Outputs structured data consumed by ALL other units

**Opinion**: Add new data transformations to `config`, not to consuming units. Config is the single point where raw HCL configs become usable module inputs.

---

# CONFIGURATION FILES (Source of Truth)

These files are the SINGLE SOURCE OF TRUTH for their domains. Never duplicate this data elsewhere.

## inventory.hcl

Hardware inventory - nodes, MACs, IPs, disks:

```hcl
locals {
  hosts = {
    node41 = {
      cluster = "live"              # Which cluster this node belongs to
      type    = "controlplane"      # controlplane | worker | none
      install = {
        disk_selector = { size = ">= 400GB" }
        arch          = "amd64"     # amd64 | arm64
      }
      interfaces = [{
        mac = "aa:bb:cc:dd:ee:ff"
        ips = ["192.168.10.41/24"]
      }]
      disks = [{
        mountpoint = "/var/lib/longhorn"
        tags       = ["fast", "ssd"]
      }]
    }
  }
}
```

## networking.hcl

Network topology - CIDRs, VIPs, domains per cluster:

```hcl
locals {
  clusters = {
    live = {
      id           = 1
      internal_tld = "internal.tomnowak.work"
      external_tld = "tomnowak.work"
      node_subnet  = "192.168.10.0/24"
      pod_subnet   = "172.18.0.0/16"
      svc_subnet   = "172.19.0.0/16"
      vip          = "192.168.10.100"
      ingress_internal_ip = "192.168.10.101"
      ingress_external_ip = "192.168.10.102"
    }
  }
}
```

## versions.hcl

Pinned software versions:

```hcl
locals {
  versions = {
    talos      = "v1.12.1"
    kubernetes = "1.34.0"
    cilium     = "1.16.5"
    flux       = "v2.4.0"
    prometheus = "20.0.0"
  }
}
```

## accounts.hcl

External service credential paths (not the credentials themselves):

```hcl
locals {
  accounts = {
    unifi = {
      url = "https://192.168.1.1"
    }
    github = {
      org  = "ionfury"
      repo = "homelab"
    }
    # Paths to secrets in AWS SSM, not actual values
  }
}
```

**Opinion**: If you need a value that exists in these files, READ it via `read_terragrunt_config()`. Never hardcode or duplicate.

---

# ANTI-PATTERNS (NEVER DO THESE)

## Terragrunt/OpenTofu Safety

- **NEVER** run `terragrunt apply` or `tofu apply` without explicit human approval
- **NEVER** use `--auto-approve` flags
- **NEVER** run `terragrunt destroy` or delete state without explicit human approval
- **NEVER** modify `.terraform.lock.hcl` manually - let Terragrunt manage it
- **NEVER** commit `.terragrunt-cache/` or `.terragrunt-stack/` directories

## Data Integrity

- **NEVER** hardcode values that exist in inventory.hcl, networking.hcl, or versions.hcl
- **NEVER** guess MAC addresses, IPs, or hostnames - verify against inventory.hcl
- **NEVER** duplicate configuration data across files
- **NEVER** put cluster-specific values in units - they belong in stacks

## State Management

- **NEVER** manually edit Terraform state
- **NEVER** run `tofu state rm` without explicit human approval
- **NEVER** work with state while another operation is in progress

---

# TESTING & VALIDATION

Testing is mandatory. No exceptions. Every infrastructure change must pass all validation before being considered ready.

## Required Validation Sequence

**Run these in order before any commit or apply request:**

```bash
# 1. Format all HCL code
task tg:fmt

# 2. Validate all stacks
task tg:validate

# 3. Plan the specific stack being changed
task tg:plan-<stack>
```

## What Each Validation Step Does

### `task tg:fmt`
- Runs `tofu fmt -recursive` on all `.tf` files
- Runs `terragrunt hclfmt` on all `.hcl` files
- **Catches**: Formatting issues, basic syntax errors
- **Must pass**: Before any other validation

### `task tg:validate`
- Runs `terragrunt stack run validate` for each stack
- **Catches**:
  - Invalid HCL syntax
  - Missing required variables
  - Invalid resource references
  - Provider configuration errors
  - Module source errors
- **Must pass**: Before planning

### `task tg:plan-<stack>`
- Runs `terragrunt stack run plan` for specific stack
- **Catches**:
  - State drift
  - Resource changes (add/change/destroy)
  - Dependency ordering issues
  - Provider API validation
- **Review carefully**: Look for unexpected destroys or changes

## Plan Output Review Checklist

When reviewing `terragrunt plan` output, verify:

1. **No unexpected destroys** - Any resource deletion should be intentional
2. **Change counts make sense** - Adding one node shouldn't change 50 resources
3. **No secrets in output** - Sensitive values should be marked `(sensitive)`
4. **Network changes are safe** - IP/CIDR changes can break connectivity
5. **Dependencies are correct** - Resources should be created in correct order

## Validation Anti-Patterns

- **NEVER** skip `task tg:fmt` - formatting errors cascade into validation failures
- **NEVER** skip `task tg:validate` - it catches errors that plan won't
- **NEVER** ignore validation warnings - they often indicate real problems
- **NEVER** approve a plan you haven't fully reviewed
- **NEVER** plan one stack and apply a different one

---

# OPERATIONS

## Task Commands

```bash
# Validation (run these first!)
task tg:fmt                    # Format all HCL files
task tg:validate               # Validate all stacks

# Planning
task tg:list                   # List available stacks
task tg:plan-<stack>           # Plan changes (e.g., task tg:plan-dev)

# Applying (REQUIRES HUMAN APPROVAL)
task tg:apply-<stack>          # Apply changes - NEVER run without approval

# Stack Management
task tg:gen-<stack>            # Generate stack from terragrunt.stack.hcl
task tg:clean-<stack>          # Clean generated stack files
```

## Workflow

1. **Format**: `task tg:fmt` - always run first
2. **Validate**: `task tg:validate` - ensure all stacks are valid
3. **Plan**: `task tg:plan-<stack>` - review changes carefully
4. **Review**: Examine plan output for unexpected changes
5. **Request Approval**: Show plan to human, explain changes
6. **Apply**: `task tg:apply-<stack>` - only after explicit human approval

## Pre-Apply Checklist

Before requesting apply approval:
- [ ] `task tg:fmt` passes with no changes needed
- [ ] `task tg:validate` passes for ALL stacks (not just the one being changed)
- [ ] `task tg:plan-<stack>` output reviewed
- [ ] No unexpected resource deletions in plan
- [ ] No unexpected resource modifications in plan
- [ ] Network changes (if any) won't break connectivity
- [ ] Changes are scoped to intended resources only

---

# CODE STYLE

## HCL Conventions

- Run `task tg:fmt` before committing (runs both `tofu fmt` and `terragrunt hclfmt`)
- Use `snake_case` for variables, locals, and resource names
- Group related locals together with comments
- Explicit is better than implicit - name resources clearly
- Use meaningful variable descriptions

```hcl
# CORRECT
locals {
  # Cluster configuration
  cluster_name = "live"
  cluster_id   = 1

  # Feature flags
  features = ["gateway-api", "longhorn", "prometheus"]
}

# INCORRECT
locals {
  name = "live"
  id = 1
  f = ["gateway-api"]
}
```

## Module Structure

Every module should have:
- `variables.tf` - Input variable definitions with descriptions
- `main.tf` - Primary resource definitions
- `outputs.tf` - Output definitions
- `versions.tf` - Provider and Terraform version constraints
- `providers.tf` - Provider configuration (if needed)

---

# COMMON TASKS

## Adding a New Machine

1. Add entry to `inventory.hcl`:
   ```hcl
   node50 = {
     cluster = "live"
     type    = "worker"
     install = {
       disk_selector = { size = ">= 400GB" }
       arch          = "amd64"
     }
     interfaces = [{
       mac = "aa:bb:cc:dd:ee:ff"  # VERIFY this is correct
       ips = ["192.168.10.50/24"] # VERIFY IP is available
     }]
     disks = [{
       mountpoint = "/var/lib/longhorn"
       tags       = ["fast", "ssd"]
     }]
   }
   ```
2. Run `task tg:plan-live` - config module auto-includes machines where `cluster == "live"`
3. Review plan output carefully
4. Request human approval for apply

## Adding a New Feature Flag

1. Add version to `versions.hcl` if the feature has a version
2. Add feature detection in `modules/config/main.tf`:
   ```hcl
   locals {
     new_feature_enabled = contains(var.features, "new-feature")
   }
   ```
3. Conditionally generate configuration based on feature flag
4. Add to stack's `features` list to enable:
   ```hcl
   # In stacks/<cluster>/terragrunt.stack.hcl
   locals {
     features = ["gateway-api", "longhorn", "new-feature"]
   }
   ```

## Adding a New Unit

1. Create `units/new-unit/terragrunt.hcl`:
   ```hcl
   include "root" {
     path = find_in_parent_folders("root.hcl")
   }

   terraform {
     source = "../../modules//new-unit"
   }

   dependency "config" {
     config_path = "../config"
     mock_outputs = {
       new_unit = {}  # Define mock for plan without config
     }
   }

   inputs = {
     config = dependency.config.outputs.new_unit
   }
   ```
2. Create corresponding module in `modules/new-unit/`
3. Add output from config module if new unit needs data
4. Add `unit` block to stacks that need it
