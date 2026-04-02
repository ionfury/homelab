# Units - Claude Reference

Terragrunt units are thin wiring layers that orchestrate OpenTofu modules. They compose modules into deployable infrastructure without implementing business logic.

For architectural context and the separation of concerns between units and modules, see [infrastructure/CLAUDE.md](../CLAUDE.md).

## Unit Inventory

| Unit | Module | Purpose | Dependencies |
|------|--------|---------|--------------|
| `config` | `modules/config` | Computes all cluster configuration; the "brain" of the stack | None |
| `unifi` | `modules/unifi` | Provisions DNS records and DHCP reservations | `config` |
| `talos` | `modules/talos` | Provisions Talos Linux cluster nodes | `config`, `unifi` |
| `bootstrap` | `modules/bootstrap` | Bootstraps Flux GitOps and cluster credentials | `config`, `talos` |
| `aws-set-params` | `modules/aws-set-params` | Stores kubeconfig/talosconfig in AWS SSM | `config`, `talos` |
| `pki` | `modules/pki` | Generates PKI certificates (Istio mesh CA) | None |
| `ingress-pki` | `modules/pki` | Generates PKI certificates (ingress CA) | None |
| `longhorn-storage` | `modules/longhorn-storage` | Provisions S3 backup buckets for all clusters (Longhorn) | None |
| `velero-storage` | `modules/velero-storage` | Provisions S3 backup buckets for all clusters (Velero) | None |

## The Config Unit

The `config` unit is the "brain" of every cluster stack. It:

1. **Reads global configuration** from parent HCL files (`inventory.hcl`, `networking.hcl`, `accounts.hcl`)
2. **Reads platform versions** from `kubernetes/platform/versions.env`
3. **Computes cluster-specific configuration** for all other units
4. **Exposes structured outputs** consumed by downstream units

### Config Outputs

Other units consume config outputs via dependency blocks:

| Output | Consumers | Description |
|--------|-----------|-------------|
| `talos` | `talos` unit | Machine configs, versions, bootstrap charts |
| `unifi` | `unifi` unit | DNS records, DHCP reservations |
| `bootstrap` | `bootstrap` unit | Cluster name, flux version, cluster vars, OCI settings |
| `aws_set_params` | `aws-set-params` unit | SSM parameter paths |
| `cluster_name` | Multiple | Cluster identifier |

## When to Add a New Unit

Add a unit only when a new lifecycle boundary is needed. See the `terragrunt` skill for the decision tree and HCL patterns.

## Stack Composition

Stacks compose units into deployable infrastructure. Cluster stacks (dev, integration, live) include: config, unifi, talos, bootstrap, aws-set-params. The global stack includes: longhorn-storage, velero-storage, pki, ingress-pki.

## Dependency Graph

Execution order: config → unifi → talos → bootstrap, aws-set-params
