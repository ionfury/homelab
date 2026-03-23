---
name: app-template
description: |
  Deploy applications using bjw-s/app-template Helm chart - a flexible chart for helmifying container images without dedicated charts.

  Use when: (1) Deploying container images that lack official Helm charts, (2) Creating HelmRelease manifests for Flux GitOps,
  (3) Configuring multi-container pods with sidecars, (4) Setting up persistent storage, ingress, services for custom applications,
  (5) Questions about app-template values structure or patterns, (6) Deploying any custom container to Kubernetes.

  Triggers: "deploy with app-template", "helmify this image", "create helm release for", "app-template values",
  "sidecar container", "multi-container pod helm", "deploy container image", "no helm chart available",
  "custom container deployment", "bjw-s", "app-template chart", "deploy docker image to kubernetes",
  "container without helm chart", "generic helm chart"
user-invocable: false
---

# app-template Helm Chart

The bjw-s/app-template chart deploys containerized applications without requiring a dedicated Helm chart. It provides a declarative interface for common Kubernetes resources.

**Chart source**: `oci://ghcr.io/bjw-s-labs/helm/app-template`
**Schema**: `https://raw.githubusercontent.com/bjw-s-labs/helm-charts/app-template-4.6.0/charts/other/app-template/values.schema.json`

## Quick Start

Minimal values.yaml for a single-container deployment:

```yaml
# yaml-language-server: $schema=https://raw.githubusercontent.com/bjw-s-labs/helm-charts/app-template-4.6.0/charts/other/app-template/values.schema.json
controllers:
  main:
    containers:
      main:
        image:
          repository: nginx
          tag: latest

service:
  main:
    controller: main
    ports:
      http:
        port: 80
```

## Security Context

| Namespace Security Level | Required |
|--------------------------|----------|
| `restricted` | `defaultPodOptions.securityContext` with `runAsNonRoot: true` + `seccompProfile: RuntimeDefault`; every container needs `allowPrivilegeEscalation: false`, `capabilities.drop: ["ALL"]`, `readOnlyRootFilesystem: true` |
| `baseline` | `defaultPodOptions.securityContext` with `runAsUser`/`fsGroup` recommended |
| `privileged` | None required |

`task k8s:validate` does NOT catch PodSecurity violations — only admission time reveals them. If an image runs as root, set `runAsUser: 65534`. If the app writes to the filesystem, use writable `emptyDir` mounts rather than disabling `readOnlyRootFilesystem`.

## Resource Limits

Resource limits prevent runaway processes, not bin-packing. The homelab hardware is heavily over-provisioned — **be generous with limits** rather than running tight to avoid OOMKills and CrashLoopBackOff. Never set CPU limits unless the workload is genuinely CPU-abusive.

| Workload Type | Memory Request | Memory Limit |
|--------------|----------------|--------------|
| Lightweight sidecar (gluetun, oauth2-proxy) | 64Mi | 256Mi |
| Web application | 128-256Mi | 512Mi-1Gi |
| Media application (qbittorrent, jellyfin) | 512Mi | 2-4Gi |
| Database (CNPG) | 256Mi | 1-2Gi |

## Flux HelmRelease Integration

For this homelab, app-template deploys via Flux ResourceSet. Add to `kubernetes/platform/helm-charts.yaml`:

```yaml
- name: "my-app"
  namespace: "default"
  chart:
    name: "app-template"
    version: "4.6.0"
    url: "oci://ghcr.io/bjw-s-labs/helm"  # Note: OCI registry
  dependsOn: [cilium]
```

Values go in `kubernetes/platform/charts/my-app.yaml`.

## References

- `references/values-reference.md` — complete field reference with all YAML examples
- `references/patterns.md` — real-world deployment examples (Vaultwarden, Home Assistant, etc.)
