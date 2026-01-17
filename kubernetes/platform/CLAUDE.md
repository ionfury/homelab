# Kubernetes Platform - Claude Reference

Centralized platform definition using Flux ResourceSets for declarative Kubernetes management.

For deploying applications with app-template, invoke the `app-template` skill.
For researching Helm chart configurations, invoke the `kubesearch` skill.

---

## Platform Structure

The Kubernetes platform uses **Flux ResourceSets** for centralized, declarative management. All Helm releases are defined in a single `helm-charts.yaml` file rather than scattered across directories.

### Key Files

| File | Purpose |
|------|---------|
| `helm-charts.yaml` | ResourceSet defining all Helm releases with versions and dependencies |
| `namespaces.yaml` | ResourceSet defining all namespaces |
| `config.yaml` | ResourceSet for config Kustomizations (non-Helm resources) |
| `kustomization.yaml` | Generates ConfigMap from chart values for Flux substitution |
| `charts/` | Helm values for each chart (one `.yaml` file per release) |
| `config/` | Non-Helm resources organized by subsystem |

### Config Subdirectories

The `config/` directory organizes non-Helm resources by concern:

| Directory | Purpose |
|-----------|---------|
| `certs/` | Certificate resources |
| `cilium/` | Cilium network policies and configs |
| `database/` | CloudNative-PG clusters and secrets |
| `garage/` | Garage object storage configs |
| `gateway/` | Gateway API resources |
| `issuers/` | Cert-manager ClusterIssuers |
| `kromgo/` | Kromgo status page configs |
| `longhorn/` | Longhorn backup and storage configs |
| `monitoring/` | Prometheus rules, Grafana dashboards |
| `secrets/` | Secret generator resources |

---

## Adding a New Helm Release

1. Add entry to `helm-charts.yaml` with name, namespace, chart details, and dependencies
2. Create `charts/<chart-name>.yaml` with Helm values
3. Add the values file to `kustomization.yaml` configMapGenerator
4. If the chart needs post-install resources, add to `config/` and reference in `config.yaml`

### ResourceSet Pattern

Helm releases are defined as inputs to a ResourceSet, which generates HelmRelease and HelmRepository resources:

```yaml
# In helm-charts.yaml
inputs:
  - name: "grafana"
    namespace: "monitoring"
    chart:
      name: "grafana"
      version: "8.8.5"
      url: "https://grafana.github.io/helm-charts"
    dependsOn: [kube-prometheus-stack]
```

**Conventions:**
- Chart versions are defined in `helm-charts.yaml`, NOT in values files
- Dependencies between releases use `dependsOn` arrays
- Values files contain only Helm chart configuration

---

## Variable Substitution

Flux performs variable substitution at reconciliation time. Use these patterns:

```yaml
# Simple substitution
url: https://grafana.${internal_domain}

# Cluster-specific (set in cluster-vars ConfigMap)
cluster: ${cluster_name}
```

**Available variables** (from cluster config):
- `${internal_domain}` - Internal TLD (e.g., internal.dev.tomnowak.work)
- `${external_domain}` - External TLD
- `${cluster_name}` - Cluster name (dev, integration, live)
- `${cluster_id}` - Numeric cluster ID

**Opinion**: Never hardcode domains or cluster names. Always use substitution.

---

## Secrets Management

**Preferred approach**: Generate secrets in-cluster using `secret-generator` (mittwald/kubernetes-secret-generator).

### In-Cluster Generated Secrets (Preferred)

For secrets that don't need to exist outside the cluster (API keys, RPC secrets, tokens), use secret-generator annotations:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-app-secret
  annotations:
    secret-generator.v1.mittwald.de/autogenerate: password,api-key
    secret-generator.v1.mittwald.de/encoding: hex      # or base64, base32, raw
    secret-generator.v1.mittwald.de/length: "32"
data: {}
```

**Benefits**:
- Self-contained clusters - no external dependencies for secrets
- Secrets auto-regenerate on cluster rebuild
- No need to manage secrets in AWS SSM

### External Secrets (When Required)

Use ExternalSecret only when secrets MUST come from outside the cluster:
- Credentials for external services (cloud APIs, SaaS integrations)
- Shared secrets that must be consistent across clusters
- Secrets needed for disaster recovery bootstrapping

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: external-api-credentials
spec:
  secretStoreRef:
    kind: ClusterSecretStore
    name: aws-ssm
  data:
    - secretKey: api-key
      remoteRef:
        key: /homelab/kubernetes/${cluster_name}/external-api-key
```

Path pattern: `/homelab/kubernetes/${cluster_name}/<secret-name>`

### Decision Tree

1. Can this secret be randomly generated? → Use `secret-generator`
2. Must this secret match a value outside the cluster? → Use `ExternalSecret`
3. Never commit secrets to git

### Required SSM Parameters for New Clusters

When bootstrapping a new cluster, populate these SSM parameters before the cluster can function fully:

| SSM Path | Description | Format |
|----------|-------------|--------|
| `/homelab/kubernetes/<cluster>/cloudflare-api-token` | Cloudflare API token for DNS challenges | JSON: `{"token": "<value>"}` |
| `/homelab/kubernetes/<cluster>/discord-webhook-secret` | Discord webhook URL for Alertmanager | Plain string: webhook URL |

**Bootstrap-managed secrets** (created by Terragrunt in kube-system):
- `external-secrets-access-key` - AWS IAM credentials for External Secrets Operator
- `heartbeat-ping-url` - Healthchecks.io ping URL (dynamically created per cluster)
- `flux-system` - GitHub token for Flux GitOps

**ExternalSecret-managed secrets** (synced from AWS SSM):
- `cloudflare-api-token` (cert-manager) - DNS challenge credentials
- `alertmanager-discord-webhook` (monitoring) - Discord notifications

---

## Code Style (YAML/Kubernetes)

- Include schema comment: `# yaml-language-server: $schema=...`
- Use `---` document separator at file start
- 2-space indentation
- Quote strings that could be misinterpreted (especially "true"/"false")

### Naming Conventions

| Resource | Convention | Example |
|----------|------------|---------|
| Helm release name | kebab-case, matches chart | `kube-prometheus-stack` |
| Namespace | kebab-case | `longhorn-system` |
| Chart values file | kebab-case, matches release | `charts/grafana.yaml` |
