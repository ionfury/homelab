# Technology Decision Rationale

This document captures the WHY behind each major technology choice in the homelab stack. The designer agent references this when evaluating new proposals to ensure consistency and cite prior reasoning.

---

## Talos Linux (over Ubuntu/Debian/Flatcar)

**Decision**: Immutable, API-driven Kubernetes OS

**Rationale**:
- **Immutable**: No SSH, no shell, no drift. The OS is a known quantity at all times
- **API-driven**: All configuration via machine configs — fully declarative, fully in git
- **Minimal attack surface**: No package manager, no unnecessary services
- **Declarative upgrades**: Tuppr handles version bumps through the same GitOps pipeline
- **Learning value**: Forces "everything as code" discipline — you can't cheat with SSH

**Rejected alternatives**:
- Ubuntu/Debian: Mutable, configuration drift, SSH temptation
- Flatcar: Similar philosophy but less Kubernetes-native, smaller ecosystem

---

## Flux (over ArgoCD)

**Decision**: Flux with ResourceSets for GitOps reconciliation

**Rationale**:
- **Native Kubernetes**: Flux uses CRDs and controllers — it IS Kubernetes, not a layer on top
- **No UI dependency**: Operates headless, driven entirely by git state
- **ResourceSets**: Powerful templating for multi-cluster, DRY configuration
- **OCI support**: First-class OCI artifact sources for the promotion pipeline
- **Lightweight**: No additional database, no Redis, no application server

**Rejected alternatives**:
- ArgoCD: Excellent tool, but the UI creates a temptation for manual operations. Heavier footprint. The pull-based model is similar, but Flux's CRD-native approach fits better with the "everything as code" principle

---

## Cilium (over Calico/Flannel)

**Decision**: eBPF-based CNI with network policy enforcement and Hubble observability

**Rationale**:
- **eBPF performance**: Kernel-level networking without iptables overhead
- **Network policies**: CiliumNetworkPolicy with L7 visibility, beyond basic NetworkPolicy
- **Hubble**: Built-in network observability — see every packet decision
- **Default deny**: Enterprise-grade network segmentation out of the box
- **Learning value**: eBPF is the future of Linux networking — valuable skill to develop

**Rejected alternatives**:
- Calico: Solid choice, but iptables-based, less observability built-in
- Flannel: Too simple for enterprise learning goals, no network policy support

---

## Longhorn (over Rook-Ceph/OpenEBS)

**Decision**: Distributed block storage with S3 backup integration

**Rationale**:
- **Simplicity**: Deploys as standard Kubernetes workload, no special kernel modules
- **Backup integration**: Native S3 backup to Garage for disaster recovery
- **UI optional**: Operates fully via CRDs, UI is informational only
- **Bare-metal friendly**: Designed for non-cloud environments
- **Incremental snapshots**: Efficient backup with delta-based snapshots

**Rejected alternatives**:
- Rook-Ceph: More powerful but significantly more complex to operate, overkill for homelab scale
- OpenEBS: Good alternative, but Longhorn's backup integration with S3 was the deciding factor

---

## Garage (over MinIO)

**Decision**: Lightweight S3-compatible distributed object storage

**Rationale**:
- **Resource efficient**: Significantly lower memory/CPU footprint than MinIO
- **Distributed**: Multi-node replication without enterprise license
- **S3 compatible**: Works with all S3-compatible tooling (Longhorn backups, CNPG backups)
- **Self-contained**: No external dependencies, simple deployment

**Rejected alternatives**:
- MinIO: Feature-rich but resource-hungry, enterprise features gated behind license

---

## CNPG (over bare PostgreSQL/Zalando operator)

**Decision**: CloudNativePG operator for PostgreSQL

**Rationale**:
- **Kubernetes-native**: Full lifecycle management via CRDs
- **Automated backups**: WAL archiving and base backups to S3 (Garage)
- **HA built-in**: Automatic failover with configurable replicas
- **PgBouncer integration**: Connection pooling managed by the operator
- **CNCF project**: Active community, production-proven

**Rejected alternatives**:
- Bare PostgreSQL: No HA, no automated backups, manual lifecycle management
- Zalando operator: Good but CNPG has stronger CNCF momentum and simpler CRD model

---

## Dragonfly (over Redis)

**Decision**: Redis-compatible in-memory data store

**Rationale**:
- **Redis compatible**: Drop-in replacement for Redis clients
- **Multi-threaded**: Better utilization of modern hardware
- **Memory efficient**: Uses less memory for equivalent workloads
- **Single binary**: Simpler deployment and operation

**Rejected alternatives**:
- Redis: The original, but single-threaded, higher memory usage, licensing concerns (post-SSPL)

---

## Terragrunt + OpenTofu (over plain Terraform/Pulumi)

**Decision**: Terragrunt for orchestration, OpenTofu for infrastructure provisioning

**Rationale**:
- **DRY infrastructure**: Terragrunt's unit/stack pattern eliminates HCL duplication
- **Open source**: OpenTofu is truly open, no licensing concerns
- **Mature ecosystem**: Vast provider ecosystem, well-understood patterns
- **State management**: Remote state with locking, per-stack isolation
- **Testing**: OpenTofu's native `.tftest.hcl` framework for infrastructure tests

**Rejected alternatives**:
- Plain Terraform: HashiCorp license change (BSL) makes OpenTofu preferable
- Pulumi: Different paradigm (imperative), smaller ecosystem, steeper learning curve for IaC

---

## GitHub Actions + OCI Promotion (over Jenkins/GitLab CI)

**Decision**: GHA for CI/CD with OCI artifact-based environment promotion

**Rationale**:
- **Native GitHub integration**: Repository-native, no separate CI server
- **OCI artifacts**: Immutable, versioned, promotion via re-tagging (not rebuilding)
- **Flux integration**: Flux ImagePolicy watches for promoted artifacts
- **Cost effective**: Free for public repositories, generous limits for private

**Rejected alternatives**:
- Jenkins: Self-hosted overhead, maintenance burden
- GitLab CI: Would require moving the repository or running a separate GitLab instance

---

## ESO + AWS SSM (over Sealed Secrets/SOPS/Vault)

**Decision**: External Secrets Operator with AWS Systems Manager Parameter Store

**Rationale**:
- **External storage**: Secrets never touch git, not even encrypted
- **AWS SSM**: Simple key-value store, no server to manage, low cost
- **ESO flexibility**: Supports multiple backends if migration needed later
- **GitOps compatible**: ExternalSecret CRs in git, actual secrets populated at runtime

**Rejected alternatives**:
- Sealed Secrets: Encrypted secrets in git — still in git, key rotation complexity
- SOPS: Similar to Sealed Secrets, encrypted-in-git approach
- Vault: Excellent but massive operational overhead for homelab scale
