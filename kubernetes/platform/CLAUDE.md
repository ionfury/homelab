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
| `garage/` | Garage object storage configs |
| `gateway/` | Gateway API resources |
| `issuers/` | Cert-manager ClusterIssuers |
| `kromgo/` | Kromgo status page configs |
| `longhorn/` | Longhorn backup and storage configs |
| `monitoring/` | Prometheus rules, Grafana dashboards |
| `secrets/` | Secret generator resources |
| `tuppr/` | Tuppr upgrade CRs (TalosUpgrade, KubernetesUpgrade) |

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
      version: "${grafana_version:-8.8.5}"    # Variable with default fallback
      url: "https://grafana.github.io/helm-charts"
    dependsOn: [kube-prometheus-stack]
```

**Conventions:**
- Chart versions use `${var:-default}` pattern (variable from `platform-versions` ConfigMap with fallback)
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

## Version Management

The `versions.env` file is the **single source of truth** for ALL platform versions. This enables:

- **Terragrunt** reads infrastructure versions for bootstrap (talos, kubernetes, cilium, flux)
- **Flux** deploys as `platform-versions` ConfigMap and substitutes into helm-charts.yaml
- **Tuppr** reads Talos/Kubernetes versions for in-cluster upgrades
- **Renovate** updates ONE file - changes flow through the promotion pipeline

### versions.env Structure

```env
# Infrastructure versions (Terragrunt + Tuppr)
talos_version=v1.12.1
kubernetes_version=1.35.0
cilium_version=1.18.6
gateway_api_version=v1.4.1
flux_version=v2.7.5
prometheus_version=26.0.0

# Helm chart versions (Flux substitution)
cert_manager_version=1.17.1
external_secrets_version=0.13.0
grafana_version=8.8.5
# ... all chart versions
```

### Natural Convergence

Terragrunt and Tuppr both read from `versions.env`, ensuring no drift:

```
Scenario: Version Upgrade via PR
──────────────────────────────────
1. PR updates versions.env → talos_version=v1.12.2
2. PR merges, Flux syncs new ConfigMap to cluster
3. Tuppr sees mismatch → executes upgrade to v1.12.2
4. Node now at v1.12.2
5. Next Terragrunt run reads versions.env → v1.12.2
6. Terragrunt sees node already at v1.12.2 → NO-OP
```

### Adding/Updating Versions

1. Edit `versions.env` with the new version
2. If adding a new Helm chart, update `helm-charts.yaml` with `${new_chart_version:-X.Y.Z}`
3. Run `task k8s:validate` to verify substitution works

---

## Tuppr Upgrades

Tuppr is a Kubernetes controller that executes Talos and Kubernetes upgrades from within the cluster, enabling GitOps-driven infrastructure upgrades.

### How It Works

1. Tuppr reads desired versions from `platform-versions` ConfigMap
2. Compares against actual node versions
3. Executes rolling upgrades (one node at a time)
4. Validates health before proceeding to next node

### Upgrade CRs

```yaml
# config/tuppr/talos-upgrade.yaml
apiVersion: tuppr.home-operations/v1alpha1
kind: TalosUpgrade
metadata:
  name: talos
spec:
  talos:
    version: ${talos_version}    # Substituted from platform-versions

# config/tuppr/kubernetes-upgrade.yaml
apiVersion: tuppr.home-operations/v1alpha1
kind: KubernetesUpgrade
metadata:
  name: kubernetes
spec:
  kubernetes:
    version: ${kubernetes_version}
```

### Triggering Upgrades

To upgrade Talos or Kubernetes:

1. Update version in `kubernetes/platform/versions.env`
2. Commit and push (or merge PR to main)
3. Flux syncs updated `platform-versions` ConfigMap
4. Tuppr detects version mismatch and executes upgrade
5. Monitor with: `kubectl -n system-upgrade logs -f -l app.kubernetes.io/name=tuppr`

### Talos API Access

Tuppr requires in-cluster API access to Talos nodes. This is enabled via `kubernetesTalosAPIAccess` in the Talos machine config:

```yaml
machine:
  features:
    kubernetesTalosAPIAccess:
      enabled: true
      allowedRoles:
        - os:admin
      allowedKubernetesNamespaces:
        - system-upgrade
```

### Separation of Concerns

| Component | Responsibility |
|-----------|----------------|
| `versions.env` | Single source of truth for ALL versions |
| Terragrunt | Initial cluster provisioning, reads from versions.env |
| Flux | Deploys charts at versions from ConfigMap |
| Tuppr | Runtime Talos/K8s upgrades |
| Renovate | Updates versions.env (single file) |

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

---

## Local Validation

Run `task k8s:validate` before committing. This validates:

1. **YAML syntax** - yamllint strict mode
2. **ResourceSet expansion** - Expands all 3 ResourceSets using `flux-operator build rset`
3. **Helm chart templating** - Templates ALL 22 charts (including OCI registries)
4. **Schema validation** - kubeconform validates all generated manifests

```bash
# Full validation (same as CI)
task k8s:validate

# With dev cluster dry-run
task k8s:dry-run-dev
```

### Static Input Provider

The `.static-provider.yaml` file provides `inputs.provider.namespace` for local ResourceSet expansion. In the cluster, this comes from the Flux ResourceSetInputProvider.

---

## Testing WAF-Protected Endpoints

The external gateway uses Coraza WAF (via Istio WasmPlugin). Testing requires SNI-aware requests.

### SNI Requirement

Istio's gateway listener matches on SNI (Server Name Indication). Raw IP requests fail:

```bash
# WRONG - no SNI, connection reset by peer
curl -kI "https://192.168.10.53/"

# CORRECT - use --resolve to send proper SNI
curl -kI --resolve "app.external.dev.tomnowak.work:443:<GATEWAY_IP>" \
  "https://app.external.dev.tomnowak.work/"
```

### Attack Pattern Testing

Test that WAF blocks common exploits (expect 403):

```bash
# SQL Injection
curl -k --resolve "app.external.dev.tomnowak.work:443:<IP>" \
  "https://app.external.dev.tomnowak.work/?id=1'%20OR%20'1'='1"

# XSS
curl -k --resolve "app.external.dev.tomnowak.work:443:<IP>" \
  "https://app.external.dev.tomnowak.work/?q=<script>alert(1)</script>"

# Command Injection
curl -k --resolve "app.external.dev.tomnowak.work:443:<IP>" \
  "https://app.external.dev.tomnowak.work/?cmd=;cat%20/etc/passwd"
```

### WAF Metrics

Coraza metrics follow this naming pattern:

| Metric | Purpose |
|--------|---------|
| `istio_requests_total{response_code="403"}` | Total blocked requests |
| `waf_filter_tx_interruptions_ruleid_<ID>_phase_<PHASE>` | Per-rule block counts |

### FAIL_OPEN Behavior

The WAF uses `failStrategy: FAIL_OPEN` - if WASM fails to load (wrong digest, image unavailable), traffic flows unfiltered. Check gateway logs for:

```
error in converting the wasm config to local: cannot fetch Wasm module...
applying allow RBAC filter
```
