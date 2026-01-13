# Terragrunt Stacks

Stacks are collections of related infrastructure units managed together. This repository uses **explicit stacks** defined via `terragrunt.stack.hcl` files.

## Stack File Structure

```hcl
# stacks/<cluster>/terragrunt.stack.hcl

locals {
  name     = "${basename(get_terragrunt_dir())}"  # Derives cluster name from directory
  features = ["gateway-api", "longhorn", "prometheus", "spegel"]
}

unit "config" {
  source = "../../units/config"
  path   = "config"
  values = {
    name     = local.name
    features = local.features
  }
}

unit "unifi" {
  source = "../../units/unifi"
  path   = "unifi"
}

unit "talos" {
  source = "../../units/talos"
  path   = "talos"
}

unit "bootstrap" {
  source = "../../units/bootstrap"
  path   = "bootstrap"
}

unit "aws_set_params" {
  source = "../../units/aws-set-params"
  path   = "aws-set-params"
}
```

## Unit Block Attributes

| Attribute | Required | Description |
|-----------|----------|-------------|
| `source` | Yes | Path to unit directory containing `terragrunt.hcl` |
| `path` | Yes | Output directory within `.terragrunt-stack/` |
| `values` | No | Key-value pairs accessible via `values.*` in unit |

## Stack Blocks (Nested Stacks)

For reusing complete stack patterns:

```hcl
stack "environment" {
  source = "git::github.com/org/catalog.git//stacks/k8s-cluster?ref=v1.0.0"
  path   = "environment"
  values = {
    cluster_name = "production"
    node_count   = 5
  }
}
```

## Stack Commands

```bash
# Generate units from stack definition
task tg:gen-<stack>              # Creates .terragrunt-stack/ directory

# Run operations across all units
task tg:plan-<stack>             # Plans all units in dependency order
task tg:apply-<stack>            # Applies all units (REQUIRES APPROVAL)
task tg:validate-<stack>         # Validates all units

# Clean generated files
task tg:clean-<stack>            # Removes .terragrunt-stack/
```

## Underlying Commands

The task commands wrap these terragrunt operations:

```bash
terragrunt stack generate --working-dir infrastructure/stacks/<stack>
terragrunt stack run plan --working-dir infrastructure/stacks/<stack>
terragrunt stack run apply --working-dir infrastructure/stacks/<stack>
terragrunt stack run validate --working-dir infrastructure/stacks/<stack>
terragrunt stack clean --working-dir infrastructure/stacks/<stack>
```

## How Stacks Work

1. **Generation**: `stack generate` reads `terragrunt.stack.hcl` and creates unit directories in `.terragrunt-stack/`
2. **Dependency Resolution**: Terragrunt analyzes `dependency` blocks across units to determine execution order
3. **Execution**: Units execute in topological order (dependencies first)
4. **Parallelism**: Independent units can run in parallel

## Generated Directory Structure

After running `task tg:gen-integration`:

```
stacks/integration/
├── terragrunt.stack.hcl        # Stack definition (source-controlled)
└── .terragrunt-stack/          # Generated (NOT committed)
    ├── config/
    │   └── terragrunt.hcl      # Copied from units/config
    ├── unifi/
    │   └── terragrunt.hcl
    ├── talos/
    │   └── terragrunt.hcl
    ├── bootstrap/
    │   └── terragrunt.hcl
    └── aws-set-params/
        └── terragrunt.hcl
```

## Values Passing

Values flow from stack to unit:

```hcl
# In terragrunt.stack.hcl
unit "config" {
  source = "../../units/config"
  path   = "config"
  values = {
    name     = local.name        # "integration"
    features = local.features    # ["gateway-api", ...]
  }
}

# In units/config/terragrunt.hcl
inputs = {
  name     = values.name         # Receives "integration"
  features = values.features     # Receives ["gateway-api", ...]
}
```

## Adding a New Stack

1. Create directory: `mkdir infrastructure/stacks/new-cluster`
2. Create stack file:

```hcl
# infrastructure/stacks/new-cluster/terragrunt.stack.hcl
locals {
  name     = "${basename(get_terragrunt_dir())}"
  features = ["gateway-api"]  # Start minimal
}

unit "config" {
  source = "../../units/config"
  path   = "config"
  values = {
    name     = local.name
    features = local.features
  }
}

# Add other units as needed
```

3. Add cluster to `networking.hcl`
4. Add machines to `inventory.hcl` with `cluster = "new-cluster"`
5. Validate: `task tg:validate`
6. Plan: `task tg:plan-new-cluster`

## Stack Limitations

- No `include` blocks in `terragrunt.stack.hcl`
- Stack-to-stack dependencies cannot use `dependency` block
- Values must be primitives, lists, or maps (no complex expressions)
