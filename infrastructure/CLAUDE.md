# Infrastructure - Claude Reference

Terragrunt/OpenTofu infrastructure that provisions bare metal to Kubernetes clusters.

For detailed procedural guidance, invoke the `terragrunt` or `opentofu-modules` skills.

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

## Testing & Validation

> For detailed testing patterns, see [infrastructure/modules/CLAUDE.md](modules/CLAUDE.md) and the `opentofu-modules` skill.

Run in order before committing:

```bash
task tg:fmt                        # Format HCL (Terragrunt + OpenTofu)
task tg:test-<module>              # Run OpenTofu native tests for a module
task tg:validate-<stack>           # Validate Terragrunt stack
```

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
- S3 buckets: `homelab-longhorn-backup-{dev,integration,live}` (Longhorn)
- S3 buckets: `homelab-velero-backup-{dev,integration,live}` (Velero, with 90-day lifecycle expiration)
- IAM users with scoped access per cluster
- SSM parameters for credential injection

**Recovery flow:**
1. Storage stack persists (never destroyed)
2. Cluster stack is rebuilt from scratch
3. Kubernetes ExternalSecrets pull credentials from SSM
4. Longhorn connects to existing backup bucket
5. Volumes restored from S3 backups

**Operational rule:** Never destroy the storage stack unless you intentionally want to lose all backup data

## Inventory Management

The `inventory.hcl` file defines all physical machines:
- **Host properties**: hostname, cluster assignment, role (controlplane/worker)
- **Network interfaces**: MAC addresses, IP addresses
- **Storage**: Disk devices for Talos installation and data

Use `hcl2json` + `jq` to query inventory data (e.g., `hcl2json < infrastructure/inventory.hcl | jq '.locals[0].hosts'`).

## AWS Authentication

Terragrunt uses S3 for remote state and DynamoDB for locking. All state operations require valid AWS credentials.

Set `AWS_PROFILE=terragrunt` and `AWS_DEFAULT_REGION=us-east-2`, then verify with `aws sts get-caller-identity`.
