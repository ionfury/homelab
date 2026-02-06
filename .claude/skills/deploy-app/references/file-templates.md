# File Templates for Application Deployment

Copy-paste templates for all configuration files needed when deploying a new application.

## versions.env Entry

```bash
# kubernetes/platform/versions.env
# Add version variable (use SCREAMING_SNAKE_CASE)
<APP_NAME>_VERSION="x.y.z"
```

## namespaces.yaml Entry

```yaml
# kubernetes/platform/namespaces.yaml - add to inputs array
- name: <namespace>
  labels:
    pod-security.kubernetes.io/enforce: baseline
```

For apps requiring elevated privileges:
```yaml
- name: <namespace>
  labels:
    pod-security.kubernetes.io/enforce: privileged
    pod-security.kubernetes.io/warn: privileged
```

## helm-charts.yaml Entry

### Standard Helm Repository

```yaml
# kubernetes/platform/helm-charts.yaml - add to inputs array
- name: "<app-name>"
  namespace: "<namespace>"
  chart:
    name: "<chart-name>"
    version: "${<APP_NAME>_VERSION}"
    url: "https://charts.example.com"
  dependsOn: [cilium]
```

### OCI Registry (GHCR, etc.)

```yaml
- name: "<app-name>"
  namespace: "<namespace>"
  chart:
    name: "<chart-name>"
    version: "${<APP_NAME>_VERSION}"
    url: "oci://ghcr.io/<org>/helm"
  dependsOn: [cilium]
```

### With Multiple Dependencies

```yaml
- name: "<app-name>"
  namespace: "<namespace>"
  chart:
    name: "<chart-name>"
    version: "${<APP_NAME>_VERSION}"
    url: "https://charts.example.com"
  dependsOn:
    - cilium
    - kube-prometheus-stack   # For apps needing monitoring CRDs
    - external-secrets        # For apps using ExternalSecret
```

## Values File (charts/<app-name>.yaml)

### Minimal Template

```yaml
# yaml-language-server: $schema=<schema-url>
# kubernetes/platform/charts/<app-name>.yaml
---
# See kubesearch.dev for real-world examples
```

### With ServiceMonitor

```yaml
# yaml-language-server: $schema=<schema-url>
---
# Enable Prometheus scraping
serviceMonitor:
  enabled: true
  interval: 30s
  scrapeTimeout: 10s

# Alternative naming conventions (check chart docs)
metrics:
  enabled: true
  serviceMonitor:
    enabled: true
```

### With Ingress (HTTPRoute preferred)

```yaml
# yaml-language-server: $schema=<schema-url>
---
# Disable chart-native ingress (use HTTPRoute instead)
ingress:
  enabled: false

# If chart requires ingress config for URL generation
ingress:
  enabled: false
  hosts:
    - host: <app-name>.${internal_domain}
```

### With Persistence

```yaml
# yaml-language-server: $schema=<schema-url>
---
persistence:
  enabled: true
  storageClass: longhorn
  size: 1Gi
  accessMode: ReadWriteOnce
```

### With Resource Limits

```yaml
# yaml-language-server: $schema=<schema-url>
---
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    memory: 512Mi
    # Note: CPU limits often cause throttling, avoid unless necessary
```

## kustomization.yaml Entry

```yaml
# kubernetes/platform/kustomization.yaml - add to configMapGenerator files
configMapGenerator:
  - name: platform-values
    files:
      # ... existing entries
      - charts/<app-name>.yaml
```

## Renovate Manager (.github/renovate.json5)

### Helm Chart Version

```json5
// .github/renovate.json5 - add to customManagers array
{
  customType: "regex",
  fileMatch: ["kubernetes/platform/versions\\.env$"],
  matchStrings: ["<APP_NAME>_VERSION=\"(?<currentValue>[^\"]+)\""],
  depNameTemplate: "<chart-name>",
  packageNameTemplate: "<registry-url>/<chart-path>",
  datasourceTemplate: "helm"
}
```

### OCI/Docker Image Version

```json5
{
  customType: "regex",
  fileMatch: ["kubernetes/platform/versions\\.env$"],
  matchStrings: ["<APP_NAME>_VERSION=\"(?<currentValue>[^\"]+)\""],
  depNameTemplate: "<image-name>",
  packageNameTemplate: "<registry>/<org>/<image>",
  datasourceTemplate: "docker"
}
```

---

## Optional: Config Directory Resources

### HTTPRoute (config/<app-name>/route.yaml)

```yaml
# kubernetes/platform/config/<app-name>/route.yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: <app-name>
spec:
  parentRefs:
    - name: internal-gateway
      namespace: gateway
  hostnames:
    - <app-name>.${internal_domain}
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: <app-name>
          port: 80
```

### External HTTPRoute

```yaml
# kubernetes/platform/config/<app-name>/route.yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: <app-name>
spec:
  parentRefs:
    - name: external-gateway
      namespace: gateway
  hostnames:
    - <app-name>.${external_domain}
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: <app-name>
          port: 80
```

### Auto-Generated Secret

```yaml
# kubernetes/platform/config/<app-name>/secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: <app-name>-secret
  annotations:
    secret-generator.v1.mittwald.de/autogenerate: "password,api-key,encryption-key"
type: Opaque
```

### ExternalSecret

```yaml
# kubernetes/platform/config/<app-name>/external-secret.yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: <app-name>-secret
spec:
  refreshInterval: 1h
  secretStoreRef:
    kind: ClusterSecretStore
    name: aws-parameter-store
  target:
    name: <app-name>-secret
    creationPolicy: Owner
  data:
    - secretKey: api-token
      remoteRef:
        key: /homelab/kubernetes/${cluster_name}/<app-name>/api-token
```

### Kustomization for Config Directory

```yaml
# kubernetes/platform/config/<app-name>/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: <namespace>
resources:
  - route.yaml
  # - secret.yaml
  # - external-secret.yaml
  # - canary.yaml
  # - prometheus-rules.yaml
```

---

## Quick Reference: Common Chart Value Patterns

| Feature | Common Keys |
|---------|-------------|
| ServiceMonitor | `serviceMonitor.enabled`, `metrics.serviceMonitor.enabled`, `prometheus.serviceMonitor.enabled` |
| Persistence | `persistence.enabled`, `storage.enabled`, `data.persistence.enabled` |
| Ingress | `ingress.enabled`, `server.ingress.enabled` |
| Resources | `resources`, `server.resources`, `controller.resources` |
| Replicas | `replicaCount`, `replicas`, `server.replicas` |
| Image | `image.repository`, `image.tag`, `controller.image.repository` |
| Secrets | `secretName`, `existingSecret`, `auth.existingSecret` |

Always check the specific chart's values.yaml or use `helm show values <chart>` for exact keys.
