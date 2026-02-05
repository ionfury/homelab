# Modules - Claude Reference

OpenTofu modules contain the implementation logic for infrastructure provisioning. Modules are pure Terraform/OpenTofu code with resources, variables, and outputs.

For architectural context (units vs modules), see [infrastructure/CLAUDE.md](../CLAUDE.md). For unit patterns that compose these modules, see [infrastructure/units/CLAUDE.md](../units/CLAUDE.md).

---

## Module Inventory

| Module | Purpose | Providers | Has Tests |
|--------|---------|-----------|-----------|
| `config` | Centralized configuration brain - computes all environment-specific settings | None (pure computation) | ✅ 9 tests |
| `talos` | Talos Linux cluster provisioning - secrets, machine configs, bootstrap | talos | ✅ 4 tests |
| `bootstrap` | Flux GitOps bootstrapping - namespaces, secrets, Helm releases | kubernetes, helm | ✅ 1 test |
| `unifi` | Network infrastructure - DNS records, DHCP reservations | unifi | ✅ 1 test |
| `pki` | Certificate authority generation and SSM storage | tls, aws | ✅ 1 test |
| `aws-set-params` | AWS SSM parameter storage | aws | ✅ 1 test |
| `longhorn-storage` | S3 backup infrastructure for Longhorn volumes | aws | ❌ |

---

## Architecture Context

### Modules = Implementation Logic

Modules contain all business logic:
- Conditional expressions based on cluster name
- Feature flag handling
- Resource provisioning
- Data transformations

### Units = Thin Wiring

Units (in `infrastructure/units/`) wire modules together:
- No business logic
- Pass configuration from config module to other modules
- Declare dependencies

### The Config Module

The `config` module is the "brain" — it:
- Reads global configuration (inventory, networking, versions)
- Computes all environment-specific settings
- Has **no providers** (pure computation)
- Exposes structured outputs consumed by other modules

Other modules receive pre-computed values, keeping them simple.

---

## Module Structure

Standard module layout:

```
modules/<name>/
├── main.tf              # Resources and data sources
├── variables.tf         # Input variable definitions
├── outputs.tf           # Output value definitions
├── versions.tf          # Provider version constraints
├── locals.tf            # Local values (optional)
├── templates/           # Template files (optional)
│   └── *.tftpl
└── tests/               # OpenTofu native tests
    ├── plan.tftest.hcl  # Basic plan test
    └── *.tftest.hcl     # Feature/edge case tests
```

### File Purposes

| File | Purpose |
|------|---------|
| `main.tf` | Primary resources and business logic |
| `variables.tf` | Input definitions with descriptions and validation |
| `outputs.tf` | Structured outputs for unit consumption |
| `versions.tf` | Required provider versions |
| `tests/*.tftest.hcl` | OpenTofu native tests |

---

## Testing Strategy

Testing uses OpenTofu native testing (`tofu test`). Every module should have tests.

### Running Tests

```bash
# Test specific module
task tg:test-<module>         # e.g., task tg:test-config

# Test all modules
task tg:test
```

### Test File Organization

| Pattern | Purpose | Example |
|---------|---------|---------|
| `plan.tftest.hcl` | Basic plan verification | All modules |
| `feature_<name>.tftest.hcl` | Feature flag tests | `feature_longhorn.tftest.hcl` |
| `validation.tftest.hcl` | Input validation tests | Config module |
| `edge_cases.tftest.hcl` | Boundary conditions | Talos, config modules |
| `<component>.tftest.hcl` | Component-specific tests | `bootstrap_charts.tftest.hcl` |

### Test Structure

```hcl
# Top-level variables set defaults for ALL run blocks
variables {
  name     = "test-cluster"
  features = ["gateway-api"]
  machines = {
    node1 = {
      cluster = "test-cluster"
      type    = "controlplane"
      # ... complete definition
    }
  }
}

# Individual test cases
run "feature_enabled" {
  command = plan

  # Override only what differs from defaults
  variables {
    features = ["prometheus"]
  }

  # Assertions
  assert {
    condition     = output.prometheus_enabled == true
    error_message = "Prometheus should be enabled"
  }
}
```

### Assertion Patterns

| Pattern | Use Case | Example |
|---------|----------|---------|
| Equality | Exact value match | `condition = output.value == "expected"` |
| Contains | List membership | `condition = contains(output.list, "item")` |
| Length | Collection size | `condition = length(output.list) == 3` |
| Not null | Value exists | `condition = output.value != null` |
| Regex | Pattern match | `condition = can(regex("^v[0-9]", output.version))` |
| Negation | Absence check | `condition = !contains(output.list, "bad")` |

### Mock Providers

Use mock providers for external dependencies:

```hcl
mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }
}

run "test_with_mocked_aws" {
  command = plan
  # Test runs without real AWS credentials
}
```

---

## Module Patterns

### Feature Flags via Set

```hcl
# variables.tf
variable "features" {
  type = set(string)
  validation {
    condition = alltrue([
      for f in var.features : contains([
        "gateway-api", "longhorn", "prometheus", "spegel"
      ], f)
    ])
    error_message = "Invalid feature flag"
  }
}

# main.tf
locals {
  longhorn_enabled = contains(var.features, "longhorn")
}
```

### Lookup with Defaults

```hcl
locals {
  storage_sizes = {
    minimal = { prometheus = "10Gi" }
    normal  = { prometheus = "50Gi" }
  }
  prometheus_size = local.storage_sizes[var.storage_provisioning].prometheus
}
```

### Structured Outputs

```hcl
# outputs.tf
output "talos" {
  description = "Talos configuration for talos unit"
  value = {
    talos_version      = var.versions.talos
    kubernetes_version = var.versions.kubernetes
    machines           = local.talos_machines
  }
}
```

### Template Files

```hcl
# main.tf
resource "local_file" "config" {
  content = templatefile("${path.module}/templates/config.tftpl", {
    cluster_name = var.name
    domain       = var.domain
  })
  filename = "${path.module}/output/config.yaml"
}
```

### Variable Validation

```hcl
variable "name" {
  type = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.name))
    error_message = "Name must be lowercase alphanumeric with hyphens"
  }
}
```

### For-Each with Computed Keys

```hcl
resource "aws_ssm_parameter" "params" {
  for_each = {
    for k, v in var.parameters : k => v
    if v != null
  }
  name  = each.key
  value = each.value
  type  = "SecureString"
}
```

---

## Common Pitfalls

| Pitfall | Problem | Solution |
|---------|---------|----------|
| Logic in units | Makes testing hard | Put all logic in config module |
| Missing mock providers | Tests require real credentials | Add mock_provider blocks |
| Incomplete test variables | Tests fail on missing required vars | Define all required vars at top level |
| Hardcoded values | Can't adapt to environments | Use variables or config module outputs |
| Missing validation | Bad inputs cause confusing errors | Add validation blocks to variables |
| Circular dependencies | Terraform fails to plan | Restructure outputs to break cycles |

---

## Adding a New Module

### Checklist

1. Create directory: `infrastructure/modules/<name>/`
2. Create core files:
   - `main.tf` - Resources
   - `variables.tf` - Inputs with descriptions
   - `outputs.tf` - Structured outputs
   - `versions.tf` - Provider requirements
3. Create tests: `tests/plan.tftest.hcl`
4. Add output to config module (if needed)
5. Create unit in `infrastructure/units/<name>/`
6. Add unit to relevant stacks
7. Run `task tg:test-<name> && task tg:validate-<stack>`

---

## Cross-References

| Document | Focus |
|----------|-------|
| [infrastructure/CLAUDE.md](../CLAUDE.md) | Architecture overview, testing philosophy |
| [infrastructure/units/CLAUDE.md](../units/CLAUDE.md) | Unit patterns that compose modules |
| [infrastructure/stacks/CLAUDE.md](../stacks/CLAUDE.md) | Stack lifecycle management |
| [opentofu-modules skill](../../.claude/skills/opentofu-modules/SKILL.md) | Detailed testing patterns |
