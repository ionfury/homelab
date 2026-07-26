# Modules - Claude Reference

OpenTofu modules contain the implementation logic for infrastructure provisioning. Modules are pure Terraform/OpenTofu code with resources, variables, and outputs.

For architectural context (units vs modules), see [infrastructure/CLAUDE.md](../CLAUDE.md). For unit patterns that compose these modules, see [infrastructure/units/CLAUDE.md](../units/CLAUDE.md).

## Module Inventory

| Module | Purpose | Providers | Has Tests |
|--------|---------|-----------|-----------|
| `config` | Centralized configuration brain - computes all environment-specific settings | None (pure computation) | ✅ 9 tests |
| `talos` | Talos Linux cluster provisioning - secrets, machine configs, bootstrap | talos | ✅ 4 tests |
| `bootstrap` | Flux GitOps bootstrapping - namespaces, secrets, Helm releases | kubernetes, helm | ✅ 1 test |
| `unifi` | Network infrastructure - DNS records, DHCP reservations | unifi | ✅ 1 test |
| `pki` | Certificate authority generation and SSM storage | tls, aws | ✅ 1 test |
| `aws-set-params` | AWS SSM parameter storage | aws | ✅ 1 test |
| `velero-storage` | S3 backup infrastructure for Velero | aws | ✅ 3 tests |

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

### Assertion Patterns

| Pattern | Use Case | Example |
|---------|----------|---------|
| Equality | Exact value match | `condition = output.value == "expected"` |
| Contains | List membership | `condition = contains(output.list, "item")` |
| Length | Collection size | `condition = length(output.list) == 3` |
| Not null | Value exists | `condition = output.value != null` |
| Regex | Pattern match | `condition = can(regex("^v[0-9]", output.version))` |
| Negation | Absence check | `condition = !contains(output.list, "bad")` |

## Common Pitfalls

| Pitfall | Problem | Solution |
|---------|---------|----------|
| Logic in units | Makes testing hard | Put all logic in config module |
| Missing mock providers | Tests require real credentials | Add mock_provider blocks |
| Incomplete test variables | Tests fail on missing required vars | Define all required vars at top level |
| Hardcoded values | Can't adapt to environments | Use variables or config module outputs |
| Missing validation | Bad inputs cause confusing errors | Add validation blocks to variables |
| Circular dependencies | Terraform fails to plan | Restructure outputs to break cycles |
