# Kubernetes Platform - Claude Reference

Centralized platform definition using Flux ResourceSets for declarative Kubernetes management.

For deploying applications with app-template, invoke the `app-template` skill.
For researching Helm chart configurations, invoke the `kubesearch` skill.

## Platform Structure

The Kubernetes platform uses **Flux ResourceSets** for centralized, declarative management. All Helm releases are defined in a single `helm-charts.yaml` file rather than scattered across directories.

### Key Files

| File | Purpose |
|------|---------|
| `versions.env` | **Single source of truth** for ALL platform versions (infrastructure + Helm charts) |
| `helm-charts.yaml` | ResourceSet defining all Helm releases with versions and dependencies |
| `namespaces.yaml` | ResourceSet defining all namespaces |
| `config.yaml` | ResourceSet for config Kustomizations (non-Helm resources) |
| `kustomization.yaml` | Generates ConfigMaps from chart values and versions.env for Flux substitution |
| `charts/` | Helm values for each chart (one `.yaml` file per release) |
| `config/` | Non-Helm resources organized by subsystem |

### Config Subdirectories

The `config/` directory organizes non-Helm resources by concern:

| Directory | Purpose |
|-----------|---------|
| `certs/` | Certificate resources |
| `cilium/` | Cilium network policies and configs |
| `database/` | CloudNative-PG clusters and secrets |
| `dragonfly/` | Dragonfly HA instance, auth, monitoring |
| `garage/` | Garage object storage configs |
| `gateway/` | Gateway API resources |
| `issuers/` | Cert-manager ClusterIssuers |
| `kromgo/` | Kromgo status page configs |
| `longhorn/` | Longhorn backup and storage configs |
| `monitoring/` | Prometheus rules, Grafana dashboards |
| `priority-classes/` | Workload scheduling priority tiers (infrastructure-critical, platform, application) |
| `secrets/` | Secret generator resources |
| `tuppr/` | Tuppr upgrade CRs (TalosUpgrade, KubernetesUpgrade) |

Alertmanager silences use the per-cluster pattern - see `kubernetes/clusters/CLAUDE.md`.

## Adding a New Helm Release

> For adding new Helm releases (ResourceSet patterns, variable substitution, HelmRelease YAML), invoke the `flux-gitops` skill.

Platform constraints:
- Check namespace security level in `namespaces.yaml` — `restricted` namespaces require full security context (see PodSecurity section).
- PriorityClass names must never use the `system-` prefix. Use `infrastructure-critical`, `platform`, or `application`.

## PodSecurity Enforcement

The `namespaces.yaml` ResourceSet assigns one of three PodSecurity profiles to each namespace:

### Namespace Security Levels

| Level | Namespaces | Implications |
|-------|-----------|--------------|
| `restricted` | cert-manager, cnpg-system, dragonfly-system, external-secrets, system, database, kromgo | Strictest: requires full security context on all pods |
| `baseline` | istio-gateway, cache, garage, garage-system | Moderate: allows some elevated capabilities (e.g., `NET_BIND_SERVICE`) |
| `privileged` | kube-system, longhorn-system, istio-system, monitoring, spegel, system-upgrade | Unrestricted: host access, BPF, privileged containers |

For required security context YAML, see the app-template or deploy-app skill.

## Config Kustomization Dependencies

The `config.yaml` ResourceSet generates Kustomizations. Always declare `dependsOn` — without it Flux reconciles in parallel, causing CRD race conditions (e.g., ExternalSecret created before its CRD exists).

### Dependency Reference

| Kustomization | dependsOn | Why |
|---------------|-----------|-----|
| `cilium-config` | `cilium`, `canary-checker` | CiliumNetworkPolicy + Canary CRDs |
| `external-secrets-stores` | `external-secrets` | ExternalSecret/ClusterSecretStore CRDs |
| `issuers` | `cert-manager`, `external-secrets-stores` | Certificate CRD + ClusterSecretStore must exist |
| `certificates` | `cert-manager`, `istiod` | Certificate CRD + Gateway for TLS |
| `longhorn-storage` | `longhorn` | RecurringJob CRD |
| `database-config` | `cloudnative-pg`, `canary-checker` | Cluster/Pooler CRDs + Canary |
| `dragonfly-config` | `dragonfly-operator`, `garage-config`, `canary-checker` | Dragonfly CRD + S3 credentials + Canary |
| `garage-config` | `garage-operator`, `canary-checker` | Garage CRDs + Canary |
| `gateway` | `istiod` | WasmPlugin CRD |
| `monitoring-config` | `kube-prometheus-stack`, `canary-checker` | PrometheusRule + Canary CRDs |
| `canary-checker-config` | `canary-checker` | Canary CRD |
| `tuppr-config` | `tuppr` | TalosUpgrade/KubernetesUpgrade CRDs |
| `priority-classes-config` | *(none)* | PriorityClass is a built-in resource (no CRDs needed) |
| `kromgo-config` | *(none)* | ConfigMap must exist BEFORE app deployment |
| `flux-notifications-config` | *(none)* | Uses only core Flux CRDs (always present) |

To find dependencies: list the CRDs your resources use → find which HelmRelease in `helm-charts.yaml` provides them → add transitive dependencies for any config Kustomization your resources reference.

## Version Management

> For Renovate annotation syntax and datasource selection, invoke the `versions-renovate` skill.

### Which file for a new version?

| Version used by | File |
|-----------------|------|
| Platform `helm-charts.yaml` | `kubernetes/platform/versions.env` |
| Cluster `resourcesets/helm-charts.yaml` | `kubernetes/clusters/<cluster>/versions.env` |
| Both platform and cluster | `kubernetes/platform/versions.env` |
| Infrastructure (Terragrunt, Tuppr) | `kubernetes/platform/versions.env` |

### Platform versions.env consumers

Terragrunt (bootstrap), Flux (`platform-versions` ConfigMap → `helm-charts.yaml`), Tuppr (Talos/K8s runtime upgrades), and shared versions like `app_template_version` used by both platform and cluster releases.

## Tuppr Upgrades

Tuppr is a Kubernetes controller that executes Talos and Kubernetes upgrades from within the cluster, enabling GitOps-driven infrastructure upgrades. See [references/tuppr.md](references/tuppr.md) for CRD templates and upgrade procedure details.

## Secrets Management

> For secret provisioning patterns (secret-generator, ExternalSecret, app-secrets module, cross-namespace replication), invoke the `secrets` skill.

See [references/bootstrap-secrets.md](references/bootstrap-secrets.md) for required SSM parameters and managed secrets when bootstrapping a new cluster.

## Istio Mesh PKI

> See [references/istio-pki.md](references/istio-pki.md) for full architecture, configuration table, and verification commands.

The mesh CA is generated by the `global` infrastructure stack (`task tg:apply-global`) and stored in AWS SSM at `/homelab/kubernetes/shared/istio-mesh-ca`. It is shared across all clusters to enable cross-cluster mTLS trust. istio-csr replaces Istio's built-in CA.

## Local Validation

Run `task k8s:validate` for full validation (YAML lint, ResourceSet expansion, Helm templating, schema validation). Run `task k8s:dry-run-dev` for server-side dry-run against dev (catches PodSecurity violations). The `.static-provider.yaml` provides `inputs.provider.namespace` for local ResourceSet expansion.
