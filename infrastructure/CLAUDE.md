# Infrastructure - Claude Reference

Terragrunt/OpenTofu infrastructure that provisions bare metal to Kubernetes clusters.

For detailed procedural guidance, invoke the `terragrunt` or `opentofu-modules` skills.

---

## Directory Structure

```
infrastructure/
├── stacks/            # Stack deployments (dev, integration, live, storage)
├── units/             # Reusable Terragrunt units (composed into stacks)
├── modules/           # OpenTofu modules (provisioning logic)
├── inventory.hcl      # Hardware inventory (hosts, IPs, MACs, disks)
├── networking.hcl     # Network topology (VLANs, subnets, gateways)
└── accounts.hcl       # External service credentials references
```

**Note:** Infrastructure versions (Talos, Kubernetes, Cilium, etc.) are read from `kubernetes/platform/versions.env` - the single source of truth for all platform versions. See `kubernetes/platform/CLAUDE.md` for details.

---

## Architecture: Units vs Modules

The infrastructure follows a clear separation of concerns between units and modules:

### Units Should Be Dumb

**Units (`infrastructure/units/`) are thin wiring layers.** They:
- Wire dependencies between modules
- Pass through configuration from the `config` module
- Contain no business logic or conditional expressions

### Config Module Centralizes Logic

**The `config` module (`infrastructure/modules/config/`) is the brain.** It:
- Computes all environment-specific configuration
- Handles conditional logic based on cluster name (dev/integration/live)
- Exposes structured outputs consumed by other modules via units

### Example: OCI Artifact Configuration

The config module defines cluster-specific OCI artifact settings:

```hcl
# infrastructure/modules/config/main.tf
locals {
  oci_config = {
    dev = {
      source_type = "git"        # Dev uses GitRepository sync
      semver      = ""
    }
    integration = {
      source_type = "oci"        # Integration uses OCIRepository
      semver      = ">= 0.0.0-0" # Accept pre-releases (the -0 suffix)
    }
    live = {
      source_type = "oci"        # Live uses OCIRepository
      semver      = ">= 0.0.0"   # Stable releases only
    }
  }
}
```

**Note:** The semver constraint alone handles version filtering. `>= 0.0.0-0` includes pre-releases (the `-0` suffix), while `>= 0.0.0` excludes them. The flux-operator does not support `semverFilter` in kustomize patches.

The bootstrap unit then simply passes through:

```hcl
# infrastructure/units/bootstrap/terragrunt.hcl
inputs = {
  source_type = dependency.config.outputs.bootstrap.source_type
  oci_semver  = dependency.config.outputs.bootstrap.oci_semver
}
```

### Why This Pattern?

1. **Testability**: Config module logic is tested via `tofu test` with assertions
2. **Single source of truth**: All environment differences live in one place
3. **Maintainability**: Adding a new cluster only requires updating the config module
4. **Visibility**: Easy to audit what differs between environments

---

## Testing & Validation

Testing is non-negotiable. Every change must pass validation before being considered ready.

### Required Validation Steps

**ALWAYS run these before requesting commit approval:**

```bash
# 1. Format all code
task tg:fmt                        # Formats HCL (Terragrunt + OpenTofu)

# 2. Run module tests (for specific module)
task tg:test-<module>              # Runs OpenTofu native tests

# 3. Validate infrastructure (for specific stack)
task tg:validate-<stack>           # Validates Terragrunt stack
```

### Validation Tools

| Tool | Purpose | Task |
|------|---------|------|
| `tofu fmt` | OpenTofu formatting | `task tg:fmt` |
| `terragrunt hclfmt` | Terragrunt HCL formatting | `task tg:fmt` |
| `terragrunt validate` | Stack validation | `task tg:validate-<stack>` |

### Testing Philosophy

- **Fail fast**: Run validation early and often during development
- **Errors are blockers**: If any validation fails, stop and fix before proceeding

---

## Infrastructure Stacks

Infrastructure is organized into stacks with different lifecycles:

| Stack | Lifecycle | Purpose |
|-------|-----------|---------|
| `storage` | Persistent | Longhorn backup buckets (S3) - never destroyed |
| `dev` | Ephemeral | Dev cluster infrastructure - can be rebuilt |
| `integration` | Ephemeral | Integration cluster infrastructure - can be rebuilt |
| `live` | Ephemeral | Production cluster infrastructure - can be rebuilt |

### Lifecycle Separation

**Backup infrastructure is decoupled from cluster lifecycle.** This ensures:
- Cluster stacks can be destroyed and rebuilt without losing backups
- Disaster recovery can restore from backups even after complete cluster loss
- Each cluster has its own S3 bucket managed by the storage stack

**Storage stack provisions:**
- S3 buckets: `homelab-longhorn-backup-{dev,integration,live}`
- IAM users with scoped access per cluster
- SSM parameters for credential injection

**Recovery flow:**
1. Storage stack persists (never destroyed)
2. Cluster stack is rebuilt from scratch
3. Kubernetes ExternalSecrets pull credentials from SSM
4. Longhorn connects to existing backup bucket
5. Volumes restored from S3 backups

**Operational rule:** Never destroy the storage stack unless you intentionally want to lose all backup data

---

## Inventory Management

Use `hcl2json` + `jq` to query inventory data:

```bash
# Get IP for a host
hcl2json < infrastructure/inventory.hcl | jq -r '.locals[0].hosts.node41.interfaces[0].addresses[0].ip'

# List all hosts
hcl2json < infrastructure/inventory.hcl | jq -r '.locals[0].hosts | keys[]'

# Get hosts in a cluster
hcl2json < infrastructure/inventory.hcl | jq -r '.locals[0].hosts | to_entries[] | select(.value.cluster == "live") | .key'
```

### Inventory Structure

The `inventory.hcl` file defines all physical machines:
- **Host properties**: hostname, cluster assignment, role (controlplane/worker)
- **Network interfaces**: MAC addresses, IP addresses
- **Storage**: Disk devices for Talos installation and data

---

## Code Style (HCL)

- Use `hcl2json` + `jq` for scripted access to HCL data
- Format with `task tg:fmt` before committing
- Use descriptive variable names that explain purpose
- Group related resources with comments explaining the grouping
