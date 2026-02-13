# Config Subsystems - Claude Reference

The `config/` directory contains non-Helm resources organized by subsystem. These are Kubernetes resources that are applied after Helm releases, including CRDs, policies, and cluster-wide configurations.

For Flux patterns and version management, see [kubernetes/platform/CLAUDE.md](../CLAUDE.md).

---

## Config Subsystem Inventory

| Subsystem | Purpose | Key Resources |
|-----------|---------|---------------|
| `canary-checker/` | Platform health validation | Canary, PrometheusRule |
| `certs/` | TLS certificates for gateways | Certificate |
| `cilium/` | Load balancer config, L2 announcements | CiliumLoadBalancerIPPool, CiliumL2AnnouncementPolicy |
| `database/` | Shared PostgreSQL cluster | Cluster, Pooler (CNPG) |
| `dragonfly/` | Shared Dragonfly (Redis) instance | Dragonfly, Secret, CiliumNetworkPolicy, PrometheusRule |
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

---

## Purpose of Config vs Helm

### When to Use Helm Values (`charts/*.yaml`)

- Resources **managed by the chart** (Deployments, Services, etc.)
- Chart-provided configuration options
- Resources that **change with chart versions**

### When to Use Config Kustomization (`config/*/`)

- **Post-install CRs** that use CRDs from Helm charts
- **Cluster-wide resources** not tied to a specific chart
- **Cross-cutting concerns** (network policies, certificates)
- Resources that **reference multiple charts** or namespaces

### Hybrid Patterns

Some subsystems use both:

| Subsystem | Helm Values | Config Resources |
|-----------|-------------|------------------|
| Longhorn | Chart deployment | StorageClass, RecurringJob |
| Monitoring | kube-prometheus-stack | Additional PrometheusRules |
| Cert-manager | Chart deployment | ClusterIssuers, Certificates |
| Cilium | CNI deployment | CiliumNetworkPolicy |

---

## Decision Tree

```
Need to add a Kubernetes resource?
│
├─ Is it a CRD instance (CR)?
│   │
│   ├─ Is the CRD from a Helm chart?
│   │   └─ YES → Add to config/<subsystem>/
│   │            Declare dependency on the HelmRelease
│   │
│   └─ Is it a built-in resource (ConfigMap, Secret)?
│       └─ Add to config/<subsystem>/ if cross-cutting
│          Or add to Helm values if chart-specific
│
├─ Is it configuration for an existing chart?
│   └─ YES → Add to charts/<chart-name>.yaml
│
└─ Is it a new application?
    └─ YES → Use Helm release in helm-charts.yaml
             Add config/ subsystem if needed for CRs
```

---

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

### Finding CRD Providers

```bash
# Check which chart provides a CRD
kubectl get crd <crd-name> -o jsonpath='{.metadata.labels}'

# Or use kubectl explain
kubectl explain <resource>
```

### Declaring Dependencies

In the config kustomization (from `kubernetes/platform/config.yaml` ResourceSet):

```yaml
inputs:
  - name: "monitoring"
    namespace: "monitoring"
    dependsOn: [kube-prometheus-stack]  # HelmRelease that provides CRDs
```

---

## Adding a New Config Subsystem

### Step 1: Create Directory Structure

```bash
mkdir -p kubernetes/platform/config/<subsystem>
```

### Step 2: Create kustomization.yaml

```yaml
# kubernetes/platform/config/<subsystem>/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - resource1.yaml
  - resource2.yaml
```

### Step 3: Add Resources

Create YAML files for your resources in the directory.

### Step 4: Register in config.yaml ResourceSet

Add entry to `kubernetes/platform/config.yaml`:

```yaml
inputs:
  - name: "<subsystem>"
    namespace: "<target-namespace>"
    dependsOn: [<helm-release-providing-crds>]
```

### Step 5: Validate

```bash
task k8s:validate
```

---

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

---

## Subsystem Deep Dives

### Network Policy Organization

**⚠️ Network policies are ENFORCED - all traffic implicitly denied unless allowed.**

See [network-policy/CLAUDE.md](network-policy/CLAUDE.md) for complete architecture and debugging.

```
network-policy/
├── baselines/           # Universal allows (DNS, health probes, Prometheus, intra-namespace)
├── profiles/            # Namespace profiles (isolated, internal, internal-egress, standard)
├── platform/            # Hand-crafted CNPs for platform namespaces
└── shared-resources/    # Opt-in access to postgres, garage-s3, kube-api
```

**Critical for app deployment**: Application namespaces MUST have `network-policy.homelab/profile=<profile>` label.

Two-tier model:
1. **Baseline CCNPs**: Universal allows applied to all pods cluster-wide
2. **Profile CCNPs**: Per-namespace ingress/egress based on namespace label

### Issuers Organization

```
issuers/
├── cloudflare-issuer/   # Public certs via DNS-01 challenge
├── homelab-ca/          # Internal CA for services
└── istio-mesh-ca/       # Istio mTLS certificates
```

### Longhorn Organization

```
longhorn/
├── backup/              # Backup target configuration
├── recurring-jobs/      # Scheduled backup jobs
├── routes/              # UI access routes
└── storage-classes/     # StorageClass definitions
```

### Priority Classes

Three tiers defined in `priority-classes/priority-classes.yaml`:

| Name | Value | Default | Purpose |
|------|-------|---------|---------|
| `infrastructure-critical` | 1000000 | No | CNI, DNS, storage, mesh data plane |
| `platform` | 900000 | No | Monitoring, logging, databases, gateways |
| `application` | 800000 | Yes | User-facing workloads (global default) |

**Naming constraint**: Never use the `system-` prefix for custom PriorityClass names. Kubernetes reserves this prefix for built-in priority classes (`system-cluster-critical`, `system-node-critical`). Names with the `system-` prefix are rejected at admission time, which causes the entire `priority-classes-config` Kustomization to fail atomically and cascades to all dependent HelmReleases.

### PodSecurity Enforcement

Multiple namespaces enforce the PodSecurity `restricted` profile, which requires strict security context settings on all pods.

**Namespaces with `restricted` enforcement** (from `namespaces.yaml`):

| Namespace | Why Restricted |
|-----------|---------------|
| `cert-manager` | Standard controller, no privileged requirements |
| `external-secrets` | Standard controller, no privileged requirements |
| `system` | Standard controller workloads |
| `database` | CNPG PostgreSQL pods run as non-root |
| `kromgo` | Simple web application |

**What `restricted` enforcement requires** (validated at admission time):

Pod-level:
- `runAsNonRoot: true`
- `seccompProfile.type: RuntimeDefault`

Container-level (every container and init container):
- `allowPrivilegeEscalation: false`
- `capabilities.drop: ["ALL"]`
- `readOnlyRootFilesystem: true` (recommended, not strictly required by restricted)
- `runAsUser: <non-zero-uid>` (if the image runs as root by default, use `65534` for `nobody`)

**Impact on Helm charts**: Any chart deployed to a `restricted` namespace MUST set these fields in its values. If the chart does not expose security context configuration, the chart cannot be deployed to that namespace without patching.

**Validation gap**: `task k8s:validate` catches schema errors but NOT PodSecurity admission violations. Only server-side dry-run (`task k8s:dry-run-dev`) or actual deployment reveals these. Agents must manually verify security context compliance when deploying to restricted namespaces.

### Monitoring Organization

The `monitoring/` subsystem is the largest, containing:
- PrometheusRules for alerting
- ServiceMonitors for scrape targets
- AlertmanagerConfig for routing
- Grafana dashboards

---

## Variable Substitution

Config resources can use Flux variable substitution:

```yaml
# In a config resource
metadata:
  name: cert-${cluster_name}  # Substituted at reconciliation
spec:
  dnsNames:
    - "*.${internal_domain}"
```

Variables come from:
- `cluster-vars` ConfigMap (cluster-specific)
- `platform-versions` ConfigMap (version pins)

See [kubernetes/platform/CLAUDE.md](../CLAUDE.md) for available variables.

---

## Cross-References

| Document | Focus |
|----------|-------|
| [kubernetes/platform/CLAUDE.md](../CLAUDE.md) | Flux patterns, version management, dependencies |
| [kubernetes/clusters/CLAUDE.md](../../clusters/CLAUDE.md) | Per-cluster overrides |
| [flux-gitops skill](../../../.claude/skills/flux-gitops/SKILL.md) | Adding Helm releases |
