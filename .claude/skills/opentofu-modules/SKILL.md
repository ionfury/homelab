---
name: opentofu-modules
description: |
  Write OpenTofu modules and tests for homelab infrastructure (infrastructure/modules/).

  Use when: creating new modules, writing or modifying .tftest.hcl test files, adding
  variables/outputs/resources, debugging test failures, or questions about tftest syntax.

  Triggers: "opentofu module", "terraform module", "tofu module", "create module",
  ".tftest.hcl", "tftest", "test my module", "module test", "infrastructure test",
  "variables.tf", "outputs.tf", "module testing", "assertion", "task tg:test", "test-config"
user-invocable: false
---

# OpenTofu Modules & Testing

Write OpenTofu modules and tests for the homelab infrastructure. Modules live in `infrastructure/modules/`, tests in `infrastructure/modules/<name>/tests/`. Run tests with `task tg:test-<module>` (e.g., `task tg:test-config`); format with `task tg:fmt`. OpenTofu version is pinned in `.opentofu-version`.

## Module Structure

Every module MUST have:
```
infrastructure/modules/<name>/
├── variables.tf    # Input definitions with descriptions and validations
├── main.tf         # Primary resources and locals
├── outputs.tf      # Output definitions
├── versions.tf     # Provider and OpenTofu version constraints
└── tests/          # Test directory
    └── *.tftest.hcl
```

## Test File Structure

Use `.tftest.hcl` extension. Define top-level `variables` for defaults inherited by all `run` blocks.

```hcl
# Top-level variables set defaults for ALL run blocks
variables {
  name     = "test-cluster"
  features = ["gateway-api", "longhorn"]

  networking = {
    id           = 1
    internal_tld = "internal.test.local"
    # ... other required fields
  }

  # Default machine - inherited unless overridden
  machines = {
    node1 = {
      cluster = "test-cluster"
      type    = "controlplane"
      install = { selector = "disk.model = *" }
      interfaces = [{
        id           = "eth0"
        hardwareAddr = "aa:bb:cc:dd:ee:01"
        addresses    = [{ ip = "192.168.10.101" }]
      }]
    }
  }
}

run "descriptive_test_name" {
  command = plan  # Use plan mode - no real resources created

  variables {
    features = ["prometheus"]  # Only override what differs
  }

  assert {
    condition     = output.some_value == "expected"
    error_message = "Descriptive failure message"
  }
}
```

## Key Patterns

Always use `command = plan` — validates configuration without creating resources. Only include variables in `run` blocks when they differ from top-level defaults; inherited variables need not be repeated. Assert against module outputs, not internal resources.

### Test Feature Flags
Test both enabled and disabled states:

```hcl
run "feature_enabled" {
  command = plan
  variables { features = ["longhorn"] }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      contains(m.install.extensions, "iscsi-tools")
    ])
    error_message = "Extension should be added when feature enabled"
  }
}

run "feature_disabled" {
  command = plan
  variables { features = [] }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      !contains(m.install.extensions, "iscsi-tools")
    ])
    error_message = "Extension should not be present without feature"
  }
}
```

### Test Validations
Use `expect_failures` to verify variable validation rules:

```hcl
run "invalid_version_rejected" {
  command = plan
  variables {
    versions = {
      talos = "1.9.0"  # Missing v prefix - should fail
      # ...
    }
  }
  expect_failures = [var.versions]
}
```

## Test Organization

Organize tests by concern:
- `plan.tftest.hcl` - Basic structure and output validation
- `validation.tftest.hcl` - Input validation rules
- `feature_<name>.tftest.hcl` - Feature flag behavior
- `edge_cases.tftest.hcl` - Boundary conditions

## Detailed Reference

For OpenTofu testing syntax, mock providers, and advanced patterns, see:
[references/opentofu-testing.md](references/opentofu-testing.md)
