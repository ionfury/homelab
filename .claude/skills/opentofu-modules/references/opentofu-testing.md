# OpenTofu Testing Reference (v1.11)

Comprehensive reference for OpenTofu native testing. For quick patterns, see the main SKILL.md.

## Table of Contents

1. [Test File Format](#test-file-format)
2. [Run Blocks](#run-blocks)
3. [Variables and Inheritance](#variables-and-inheritance)
4. [Assertions](#assertions)
5. [Expected Failures](#expected-failures)
6. [Mock Providers](#mock-providers)
7. [Override Blocks](#override-blocks)
8. [CLI Options](#cli-options)

---

## Test File Format

OpenTofu recognizes these extensions (in priority order):
1. `.tofutest.hcl` / `.tofutest.json` (OpenTofu-specific)
2. `.tftest.hcl` / `.tftest.json` (Terraform-compatible)

This repository uses `.tftest.hcl` for compatibility.

### File Location

Tests live in `tests/` subdirectory within each module:
```
infrastructure/modules/config/
├── main.tf
├── variables.tf
├── outputs.tf
└── tests/
    ├── plan.tftest.hcl
    ├── validation.tftest.hcl
    └── feature_longhorn.tftest.hcl
```

---

## Run Blocks

Each `run` block executes either `plan` or `apply`, then validates assertions.

```hcl
run "test_name" {
  command = plan  # or apply (default: apply)

  variables {
    key = "value"
  }

  assert {
    condition     = expression
    error_message = "Failure description"
  }
}
```

### Run Block Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `command` | `plan` or `apply` | Execution mode (default: `apply`) |
| `variables` | block | Override file-level variables |
| `assert` | block(s) | Validation conditions |
| `expect_failures` | list | Resources expected to fail validation |
| `plan_options` | block | Configure refresh, mode, replace, target |
| `module` | block | Load alternate module for testing |
| `providers` | map | Override provider configurations |

### Sequential Execution

Run blocks execute in order. Later blocks can reference outputs from earlier blocks:

```hcl
run "setup" {
  command = plan
  # Creates output.cluster_name
}

run "verify" {
  command = plan
  variables {
    dependent_value = run.setup.cluster_name
  }
}
```

---

## Variables and Inheritance

### Resolution Order (lowest to highest priority)

1. Environment variables (`TF_VAR_` prefix)
2. `terraform.tfvars` in module directory
3. `*.auto.tfvars` in module directory
4. `tests/terraform.tfvars`
5. `tests/*.auto.tfvars`
6. `-var` and `-var-file` CLI arguments
7. Test file `variables` block (top-level)
8. Individual `run` block `variables` block

### Top-Level Variables

Define defaults inherited by all `run` blocks:

```hcl
variables {
  name     = "test-cluster"
  features = ["gateway-api"]

  networking = {
    id           = 1
    internal_tld = "test.local"
    # ...
  }
}

run "test1" {
  # Inherits all variables above
  command = plan
}

run "test2" {
  command = plan
  variables {
    features = ["prometheus"]  # Override only this
    # name and networking inherited
  }
}
```

---

## Assertions

Assertions validate conditions using OpenTofu expressions.

```hcl
assert {
  condition     = <boolean expression>
  error_message = "Description of expected behavior"
}
```

### Condition Expressions

Assertions can reference:
- `output.<name>` - Module outputs
- `var.<name>` - Input variables
- `local.<name>` - Local values
- `resource_type.name` - Resources (with apply mode)
- `data.data_type.name` - Data sources
- `run.<block_name>.<output>` - Outputs from previous run blocks

### Multiple Assertions

Stack multiple assertions in a single run block:

```hcl
run "comprehensive_test" {
  command = plan

  assert {
    condition     = length(output.machines) == 2
    error_message = "Expected 2 machines"
  }

  assert {
    condition     = output.cluster_endpoint == "k8s.test.local"
    error_message = "Endpoint mismatch"
  }

  assert {
    condition     = output.talos.kubernetes_version == "1.32.0"
    error_message = "Version mismatch"
  }
}
```

### Complex Conditions

```hcl
# All items match condition
condition = alltrue([
  for item in output.list : item.enabled
])

# Any item matches condition
condition = anytrue([
  for item in output.list : item.name == "target"
])

# Nested object access
condition = anytrue([
  for label in output.machines["node1"].labels :
  label.key == "app" && label.value == "web"
])

# String operations
condition = strcontains(output.config, "expected_substring")
condition = startswith(output.url, "https://")
condition = endswith(output.filename, ".yaml")

# Type checks
condition = can(tonumber(output.value))
condition = output.list != null && length(output.list) > 0
```

---

## Expected Failures

Test that invalid inputs are correctly rejected:

```hcl
run "invalid_input_rejected" {
  command = plan

  variables {
    instances = -1  # Invalid: negative count
  }

  expect_failures = [
    var.instances,  # Expect validation to fail
  ]
}
```

### Multiple Expected Failures

```hcl
run "multiple_validations" {
  command = plan

  variables {
    talos_version      = "1.9.0"  # Missing v prefix
    kubernetes_version = "v1.32"  # Has v prefix (wrong)
  }

  expect_failures = [
    var.talos_version,
    var.kubernetes_version,
  ]
}
```

---

## Mock Providers

Replace real providers with mocked versions for isolated testing.

```hcl
mock_provider "aws" {
  alias = "mock"

  mock_resource "aws_s3_bucket" {
    defaults = {
      arn    = "arn:aws:s3:::mock-bucket"
      region = "us-east-1"
    }
  }

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }
}

run "with_mocked_aws" {
  providers = {
    aws = aws.mock
  }
}
```

### Auto-Generated Mock Values

When defaults aren't specified, OpenTofu generates:
- Numbers: `0`
- Booleans: `false`
- Strings: Random alphanumeric
- Collections: Empty `[]` or `{}`

---

## Override Blocks

Skip actual provider calls for specific resources/data sources.

### Override Resource

```hcl
override_resource {
  target = aws_s3_bucket.test
  values = {
    arn    = "arn:aws:s3:::test-bucket"
    bucket = "test-bucket"
  }
}

run "with_override" {
  command = plan
  # aws_s3_bucket.test won't call AWS API
}
```

### Override Data Source

```hcl
override_data {
  target = data.aws_caller_identity.current
  values = {
    account_id = "123456789012"
    arn        = "arn:aws:iam::123456789012:user/test"
  }
}
```

### Override Module

Replace entire module output:

```hcl
override_module {
  target = module.vpc
  outputs = {
    vpc_id     = "vpc-12345"
    subnet_ids = ["subnet-a", "subnet-b"]
  }
}
```

### Scope to Run Block

Overrides can be scoped to specific run blocks:

```hcl
run "with_specific_override" {
  command = plan

  override_resource {
    target = local_file.config
    values = {
      content  = "mocked content"
      filename = "/tmp/test.txt"
    }
  }
}
```

---

## CLI Options

```bash
# Run all tests in module
tofu test

# Run specific test file
tofu test -filter=tests/plan.tftest.hcl

# Run with custom test directory
tofu test -test-directory=./custom-tests

# Pass variables
tofu test -var 'name=custom-cluster'
tofu test -var-file=test.tfvars

# Verbose output (show plan/state)
tofu test -verbose

# JSON output for CI
tofu test -json
```

### Repository Task Commands

Always use task commands instead of direct `tofu test`:

```bash
# Test specific module
task tg:test-config
task tg:test-talos
task tg:test-bootstrap

# Format before testing
task tg:fmt
```

The task commands handle:
- Working directory setup
- `tofu init -upgrade` before test
- Proper environment configuration

---

## OpenTofu v1.11 Features

### Ephemeral Values

Values that exist only in memory, never persisted to state:

```hcl
variable "api_key" {
  type      = string
  ephemeral = true
}

output "temporary_token" {
  value     = data.external.token.result
  ephemeral = true
}
```

### Enabled Meta-Argument

Conditional resource creation alternative to `count`:

```hcl
resource "aws_instance" "optional" {
  lifecycle {
    enabled = var.create_instance
  }
  # ...
}
```

Use when:
- You need 0 or 1 instances (not N)
- Avoiding count index complexity
- The resource has naming conflicts with count/for_each
