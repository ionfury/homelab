# Config Subsystems - Claude Reference

The `config/` directory contains non-Helm resources organized by subsystem. These are Kubernetes resources that are applied after Helm releases, including CRDs, policies, and cluster-wide configurations.

For Flux patterns and version management, see [kubernetes/platform/CLAUDE.md](../CLAUDE.md).

> For Flux ResourceSet patterns and HelmRelease management, invoke the `flux-gitops` skill.
> For secret provisioning (secret-generator, ExternalSecret, replication), invoke the `secrets` skill.
> For network policy configuration and Hubble debugging, invoke the `network-policy` skill.

## Config Subsystem Inventory

| Subsystem | Purpose | Key Resources |
|-----------|---------|---------------|
| `canary-checker/` | Platform health validation | Canary, PrometheusRule |
| `certs/` | TLS certificates for gateways | Certificate |
| `cilium/` | Load balancer config, L2 announcements | CiliumLoadBalancerIPPool, CiliumL2AnnouncementPolicy |
| `database/` | Shared PostgreSQL cluster | Cluster, Pooler (CNPG) |
| `dragonfly/` | Shared Dragonfly (Redis) cache (deployed to `cache` namespace) | Dragonfly, Secret, PrometheusRule |
| `flux-notifications/` | Flux alert providers and routing | Provider, Alert |
| `garage/` | S3-compatible object storage | GarageCluster |
| `gateway/` | Gateway API resources and WAF | Gateway, HTTPRoute, WasmPlugin |
| `issuers/` | Certificate issuers | ClusterIssuer (3 types) |
| `kromgo/` | Status page metrics | ConfigMap, HTTPRoute |
| `longhorn/` | Storage classes, backup config | StorageClass, RecurringJob |
| `monitoring/` | Alertmanager config, alert rules | PrometheusRule, ServiceMonitor, AlertmanagerConfig |
| `network-policy/` | Cilium network policies | CiliumNetworkPolicy, CiliumClusterwideNetworkPolicy |
| `priority-classes/` | Workload scheduling tiers | PriorityClass (infrastructure-critical, platform, application) |
| `secrets/` | External secrets infrastructure | ClusterSecretStore |
| `tuppr/` | Talos and Kubernetes upgrades | TalosUpgrade, KubernetesUpgrade |

## Config vs Helm Decision

CRD instances go in `config/<subsystem>/` with `dependsOn` on the HelmRelease that provides the CRD; chart configuration goes in `charts/`; new apps go in `helm-charts.yaml`.

## CRD Dependencies

Config kustomizations must declare dependencies on the HelmReleases that provide their CRDs.

### Quick Reference

| CRD | Provided By (HelmRelease) |
|-----|---------------------------|
| `Certificate`, `ClusterIssuer` | cert-manager |
| `CiliumNetworkPolicy`, `CiliumLoadBalancerIPPool` | cilium |
| `Cluster`, `Pooler` (CNPG) | cloudnative-pg |
| `Dragonfly` | dragonfly-operator |
| `Canary` | canary-checker |
| `Gateway`, `HTTPRoute` | (Gateway API CRDs - pre-installed) |
| `PrometheusRule`, `ServiceMonitor` | kube-prometheus-stack |
| `Silence` | silence-operator |
| `TalosUpgrade`, `KubernetesUpgrade` | tuppr |
| `WasmPlugin` | istio-istiod |
| `GarageCluster` | garage |

Use `kubectl get crd <name> -o jsonpath='{.metadata.labels}'` or `kubectl explain <resource>` to find the providing chart.

## Naming Conventions

### Directory Naming

- Use **kebab-case**: `network-policy`, `flux-notifications`
- Match the **primary concern**: `monitoring` (not `prometheus-rules`)
- Group related resources: `longhorn/` contains storage-classes, backup, recurring-jobs

### File Naming

| Pattern | Use Case | Example |
|---------|----------|---------|
| `<resource-type>.yaml` | Single resource of type | `storageclass.yaml` |
| `<name>-<type>.yaml` | Multiple of same type | `prometheus-rules.yaml` |
| `kustomization.yaml` | Directory aggregation | Required in each dir |

### Resource Naming

- Use cluster/namespace context: `homelab-ingress-ca` (not just `ca`)
- Include subsystem prefix when ambiguous: `longhorn-backup-daily`

## Variable Substitution

Use `${cluster_name}`, `${internal_domain}`, `${external_domain}`, `${cluster_id}` for cluster-specific values. See [kubernetes/platform/CLAUDE.md](../CLAUDE.md) for full variable list.

## PodSecurity Enforcement

Namespaces with `restricted` enforcement (cert-manager, cnpg-system, dragonfly-system, external-secrets, system, database, kromgo) reject pods that do not comply at admission time.

**Quick mapping** — see [kubernetes/platform/CLAUDE.md](../CLAUDE.md) for the full namespace security levels table.

For required security context YAML, see the app-template or deploy-app skill.

## Network Policy

**All traffic is implicitly denied.** Application namespaces MUST have the `network-policy.homelab/profile` label set. See [network-policy/CLAUDE.md](network-policy/CLAUDE.md) for complete architecture. For profile selection, access labels, and Hubble debugging, invoke the `network-policy` skill.
