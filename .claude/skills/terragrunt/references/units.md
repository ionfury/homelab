# Terragrunt Units

A unit is the fundamental deployable component—a directory containing a `terragrunt.hcl` file that wraps a Terraform/OpenTofu module.

## Unit Structure

```
units/<name>/
└── terragrunt.hcl
```

Each unit:
- References a module in `modules/<name>/`
- Declares dependencies on other units
- Passes inputs to the module
- Provides mock outputs for planning

## Complete Unit Example

```hcl
# units/talos/terragrunt.hcl

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../.././/modules/talos"
}

dependency "config" {
  config_path = "../config"

  mock_outputs = {
    talos = {
      talos_version      = "v1.12.0"
      kubernetes_version = "1.34.0"
      talos_machines = [
        {
          install = { selector = "disk.model = *" }
          config  = <<EOT
cluster:
  clusterName: talos.local
  controlPlane:
    endpoint: https://talos.local:6443
machine:
  type: controlplane
  network:
    hostname: mock-controlplane-1
    interfaces:
      - addresses:
        - 10.10.10.10/24
EOT
        }
      ]
      on_destroy             = { graceful = false, reboot = true, reset = true }
      talos_config_path      = "~/.talos"
      kubernetes_config_path = "~/.kube"
      talos_timeout          = "10m"
      bootstrap_charts       = []
    }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = dependency.config.outputs.talos
```

## Key Blocks

### include "root"

Inherits configuration from `root.hcl`:

```hcl
include "root" {
  path = find_in_parent_folders("root.hcl")
}
```

The root.hcl provides:
- Remote state configuration (S3 backend)
- Catalog URLs for module sources
- Common inputs from accounts.hcl

### terraform

Points to the OpenTofu/Terraform module:

```hcl
terraform {
  source = "../../../.././/modules/talos"
}
```

Path patterns:
- `../../../.././/modules/talos` - Local module with double-slash for proper caching
- `git::github.com/org/repo.git//modules/talos?ref=v1.0.0` - Remote module

### dependency

Declares prerequisite units and accesses their outputs:

```hcl
dependency "config" {
  config_path = "../config"

  # Mock outputs for plan/validate when dependency hasn't been applied
  mock_outputs = {
    talos = { ... }
  }

  # Only use mocks for these commands
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}
```

### inputs

Passes values to the module:

```hcl
inputs = dependency.config.outputs.talos

# Or with multiple sources:
inputs = {
  name       = values.name                    # From stack's values block
  networking = local.networking_vars.locals   # From read_terragrunt_config
  config     = dependency.config.outputs.talos
}
```

## Reading Configuration Files

Units can read sibling `.hcl` files:

```hcl
locals {
  networking_vars = read_terragrunt_config(find_in_parent_folders("networking.hcl"))
  inventory_vars  = read_terragrunt_config(find_in_parent_folders("inventory.hcl"))
  versions_vars   = read_terragrunt_config(find_in_parent_folders("versions.hcl"))
  accounts_vars   = read_terragrunt_config(find_in_parent_folders("accounts.hcl"))
}

inputs = {
  networking = local.networking_vars.locals.clusters[values.name]
  machines   = local.inventory_vars.locals.hosts
}
```

## Accessing Stack Values

Units receive values from their stack's `values = { }` block:

```hcl
# In stack's terragrunt.stack.hcl
unit "config" {
  source = "../../units/config"
  path   = "config"
  values = {
    name     = local.name
    features = local.features
  }
}

# In units/config/terragrunt.hcl
inputs = {
  name     = values.name      # "integration", "live", etc.
  features = values.features  # ["gateway-api", "longhorn", ...]
}
```

## Mock Outputs

Mock outputs enable `plan` and `validate` before dependencies are applied:

```hcl
dependency "config" {
  config_path = "../config"

  mock_outputs = {
    # Structure must match real outputs
    unifi = {
      dns_records       = []
      dhcp_reservations = []
    }
  }

  # Limit mock usage to non-apply commands
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}
```

Guidelines for mocks:
- Match the shape of real outputs exactly
- Use minimal placeholder values
- Include all required fields
- Never use mocks during apply

## Generate Blocks

Dynamically inject configuration files:

```hcl
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "us-east-2"
  assume_role {
    role_arn = "arn:aws:iam::123456789:role/terragrunt"
  }
}
EOF
}
```

## Creating a New Unit

1. Create the unit directory:
```bash
mkdir infrastructure/units/new-unit
```

2. Create `terragrunt.hcl`:
```hcl
include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../.././/modules/new-unit"
}

dependency "config" {
  config_path = "../config"
  mock_outputs = {
    new_unit = {}
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = dependency.config.outputs.new_unit
```

3. Create the module in `modules/new-unit/`:
```
modules/new-unit/
├── main.tf
├── variables.tf
├── outputs.tf
├── versions.tf
└── tests/
    └── plan.tftest.hcl
```

4. Add output to config module in `modules/config/outputs.tf`:
```hcl
output "new_unit" {
  value = {
    # Structured data for the new unit
  }
}
```

5. Add to stacks:
```hcl
# In stacks/<cluster>/terragrunt.stack.hcl
unit "new_unit" {
  source = "../../units/new-unit"
  path   = "new-unit"
}
```

## Unit Dependency Patterns

### Linear Dependencies

```
config → talos → bootstrap
```

```hcl
# units/talos/terragrunt.hcl
dependency "config" {
  config_path = "../config"
}

# units/bootstrap/terragrunt.hcl
dependency "talos" {
  config_path = "../talos"
}
```

### Parallel Dependencies

```
config → unifi
      → talos → bootstrap
             → aws-set-params
```

`unifi` and `talos` run in parallel after `config`.
`bootstrap` and `aws-set-params` run in parallel after `talos`.

### Ordering Without Data

When you need ordering but don't consume outputs:

```hcl
dependencies {
  paths = ["../config"]
}
```

## Local Development

Override remote sources during development:

```bash
# Apply with local module source
terragrunt apply --source ../../../modules//talos
```

Terragrunt caches downloads. For rapid iteration, use local paths.
