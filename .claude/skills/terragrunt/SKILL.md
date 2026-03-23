---
name: terragrunt
description: |
  Homelab infrastructure management with Terragrunt and OpenTofu.

  Use when: adding/modifying machines in inventory.hcl, creating or updating units and stacks,
  working with feature flags, running validation (fmt, validate, test, plan), understanding the
  units→stacks→modules architecture, or working with HCL configuration files.

  Triggers: "terragrunt", "terraform", "opentofu", "tofu", "infrastructure code", "IaC",
  "inventory.hcl", "networking.hcl", "HCL files", "add machine", "add node", "cluster provisioning",
  "bare metal", "talos config", "task tg:", "infrastructure plan", "infrastructure apply",
  "stacks", "units", "modules architecture"
user-invocable: false
---

# Terragrunt Infrastructure Skill

Manage bare-metal Kubernetes infrastructure from PXE boot to running clusters.

For architecture overview (units vs modules, config centralization), see [infrastructure/CLAUDE.md](../../infrastructure/CLAUDE.md). For detailed unit patterns, see [infrastructure/units/CLAUDE.md](../../infrastructure/units/CLAUDE.md).

## Task Commands (Always Use These)

```bash
# Validation (run in order)
task tg:fmt                    # Format HCL files
task tg:test-<module>          # Test specific module (e.g., task tg:test-config)
task tg:validate-<stack>       # Validate stack (e.g., task tg:validate-integration)

# Operations
task tg:list                   # List available stacks
task tg:plan-<stack>           # Plan (e.g., task tg:plan-integration)
task tg:apply-<stack>          # Apply (REQUIRES HUMAN APPROVAL)
task tg:gen-<stack>            # Generate stack files
task tg:clean-<stack>          # Clean generated files
```

**NEVER** run `terragrunt` or `tofu` directly—always use `task` commands.

## How to Add a Machine

Edit `inventory.hcl` → run `task tg:plan-live` → review plan (config module auto-includes machines where `cluster == "live"`) → request human approval before apply.

```hcl
node50 = {
  cluster = "live"
  type    = "worker"
  install = {
    selector     = "disk.model == 'Samsung'"
    architecture = "amd64"
  }
  interfaces = [{
    id           = "eth0"
    hardwareAddr = "aa:bb:cc:dd:ee:ff"  # VERIFY correct
    addresses    = [{ ip = "192.168.10.50" }]  # VERIFY available
  }]
}
```

## How to Add a Feature Flag

Add version to `versions.hcl` if needed → add feature detection in `modules/config/main.tf` (`contains(var.features, "new-feature")`) → enable in the stack's features list (`features = ["gateway-api", "longhorn", "new-feature"]`).

## How to Create a New Unit

Create `units/new-unit/terragrunt.hcl` (include root, point to module source, declare `dependency "config"` with mock_outputs, set `inputs = dependency.config.outputs.new_unit`) → create `modules/new-unit/` with `variables.tf`, `main.tf`, `outputs.tf`, `versions.tf` → add output from config module → add `unit` block to stacks that need it. See [units.md](references/units.md) for the full unit template.

For module tests, see the [opentofu-modules skill](../opentofu-modules/SKILL.md). Run with `task tg:test-config` or `task tg:test` for all modules.

## Important

- **NEVER** guess MAC addresses or IPs—verify against `inventory.hcl`
- **NEVER** commit `.terragrunt-cache/` or `.terragrunt-stack/`
- **NEVER** manually edit Terraform state

## State Operations

When removing state entries with indexed resources (e.g., `this["rpi4"]`), `xargs` strips the quotes causing errors. Use a `while` loop instead:

```bash
# WRONG - xargs mangles quotes in resource names
terragrunt state list | xargs -n 1 terragrunt state rm

# CORRECT - while loop preserves quotes
terragrunt state list | while read -r resource; do terragrunt state rm "$resource"; done
```

This applies to any state operation on resources with map keys like `data.talos_machine_configuration.this["rpi4"]`.

## Validation Checklist

`task tg:fmt` → `task tg:test` (if module tests exist) → `task tg:validate-<stack>` for ALL stacks → `task tg:plan-<stack>` reviewed (no unexpected destroys, network changes won't break connectivity).

## References

- [stacks.md](references/stacks.md) - Detailed Terragrunt stacks documentation
- [units.md](references/units.md) - Detailed Terragrunt units documentation
