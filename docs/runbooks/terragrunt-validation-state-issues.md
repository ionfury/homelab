# Terragrunt Validation State Issues

Resolve `terragrunt validate` failures caused by partial state in dependency units.

## Prerequisites

- Terragrunt and OpenTofu installed (via `brew bundle`)
- AWS credentials configured for S3 state backend access

## Indication

Use this runbook when:
- `task tg:validate-<stack>` fails with "Unsupported attribute" errors
- Error messages reference missing outputs like `kubeconfig_host`, `kubeconfig_raw`
- A dependency unit (e.g., talos) has been partially applied but not completed

## Root Cause

Terragrunt's `mock_outputs` only activate when a dependency has **no state**. If partial state exists (from incomplete apply), terragrunt uses real outputs instead of mocks. Missing outputs cause validation failures.

Example error:
```
on ./.terragrunt-stack/bootstrap/terragrunt.hcl line 48:
  48:     host = dependency.talos.outputs.kubeconfig_host
This object does not have an attribute named "kubeconfig_host".
```

## Remediation

### Option 1: Enable Mock Output Merging (Recommended)

Add `mock_outputs_merge_strategy_with_state = "shallow"` to the dependency block. This merges mock outputs with existing partial state.

```hcl
dependency "talos" {
  config_path = "../talos"

  mock_outputs = {
    kubeconfig_host                   = "https://localhost:6443"
    kubeconfig_client_certificate     = "mock"
    kubeconfig_client_key             = "mock"
    kubeconfig_cluster_ca_certificate = "mock"
  }
  mock_outputs_allowed_terraform_commands  = ["init", "validate", "plan", "destroy"]
  mock_outputs_merge_strategy_with_state = "shallow"
}
```

**Files requiring this pattern:**
- `infrastructure/units/bootstrap/terragrunt.hcl` (talos dependency)
- `infrastructure/units/aws-set-params/terragrunt.hcl` (talos dependency)

### Option 2: Clear Partial State

If Option 1 doesn't apply or you want a clean slate:

```bash
# Check current state
cd infrastructure/stacks/<stack>/.terragrunt-stack/<unit>
terragrunt state list

# Remove specific resources
terragrunt state rm <resource_address>

# Or remove all state for the unit (nuclear option)
aws s3 rm s3://homelab-terragrunt-remote-state/infrastructure/stacks/<stack>/.terragrunt-stack/<unit>/terraform.tfstate
```

### Option 3: Complete the Deployment

If the infrastructure should exist, complete the apply:

```bash
task tg:apply-<stack>
```

## Verification

```bash
# Re-run validation
task tg:validate-<stack>

# Expected output
❯❯ Run Summary  5 units  13s
   ────────────────────────────
   Succeeded    5
```

## Prevention

Always include `mock_outputs_merge_strategy_with_state = "shallow"` when defining dependencies on units that:
1. May be partially applied during development
2. Produce outputs needed by downstream units
3. Have complex provisioning that may fail mid-way (e.g., talos, bootstrap)
