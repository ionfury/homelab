---
name: flux-gitops
description: |
  Flux GitOps patterns for the homelab Kubernetes platform using ResourceSets.

  Use when: (1) Adding new Helm releases or applications to the platform, (2) Deploying a new service to Kubernetes,
  (3) Debugging Flux reconciliation issues or sync problems, (4) Understanding ResourceSet patterns,
  (5) Configuring Kustomizations and variable substitution, (6) Questions about helm-charts.yaml or platform structure,
  (7) GitOps workflow questions.

  Triggers: "add helm release", "deploy to kubernetes", "add new service", "add application",
  "flux resourceset", "flux reconciliation", "flux not syncing", "flux stuck", "gitops",
  "helm-charts.yaml", "platform values", "flux debug", "HelmRelease not ready", "kustomization",
  "helmrelease", "add chart", "deploy helm chart"
user-invocable: false
---

# Flux GitOps Platform

The homelab Kubernetes platform uses Flux ResourceSets for centralized, declarative management of Helm releases and configurations.

For ResourceSet patterns, version management, and platform architecture, see [kubernetes/platform/CLAUDE.md](../../kubernetes/platform/CLAUDE.md).

## How to Add a New Helm Release

Add to `helm-charts.yaml` inputs → create `charts/<release-name>.yaml` values file → register in `kustomization.yaml` configMapGenerator → optionally add `config/<name>/` resources.

### helm-charts.yaml entry

```yaml
inputs:
  - name: "my-new-chart"
    namespace: "my-namespace"
    chart:
      name: "actual-chart-name"
      version: "${my_chart_version}"   # From versions.env via Flux substitution
      url: "https://example.com/charts"
    dependsOn: [cilium]
```

For OCI registries, prefix url with `oci://`:
```yaml
    chart:
      url: "oci://ghcr.io/bjw-s/helm"
```

The ResourceSet template auto-detects OCI URLs and sets `type: oci` on the HelmRepository.

### Values file

Create `charts/<release-name>.yaml`:
```yaml
# yaml-language-server: $schema=<chart-schema-url>
---
replicas: 1
```

### kustomization.yaml registration

```yaml
configMapGenerator:
  - name: platform-values
    files:
      - charts/my-new-chart.yaml
```

### PodSecurity compliance

Check the target namespace's security level in `namespaces.yaml`. For `restricted` namespaces (cert-manager, external-secrets, system, database, kromgo), every container requires:

```yaml
# Pod-level
podSecurityContext:
  runAsNonRoot: true
  seccompProfile:
    type: RuntimeDefault

# Container-level (every container including init containers)
securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop: ["ALL"]
  readOnlyRootFilesystem: true
  runAsNonRoot: true
  seccompProfile:
    type: RuntimeDefault
```

If the image runs as root, set `runAsUser: 65534`. `task k8s:validate` does NOT catch PodSecurity violations — only admission time reveals them.

## ResourceSet Template Syntax

The `resourcesTemplate` uses Go text/template with `<<` `>>` delimiters. See [templates.md](templates.md) for full template examples.

Key functions:
- `<< inputs.field >>` — access input field
- `<<- if condition >>` / `<<- end >>` — conditional (leading `-` trims whitespace)
- `<<- range $item := inputs.array >>` — loop
- `hasPrefix "oci://" inputs.chart.url` — string prefix check

## Dependency Management

Release dependencies (waits for other HelmReleases):
```yaml
inputs:
  - name: "grafana"
    dependsOn: [kube-prometheus-stack, alloy]
```

ResourceSet dependencies (waits for another ResourceSet):
```yaml
spec:
  dependsOn:
    - apiVersion: fluxcd.controlplane.io/v1
      kind: ResourceSet
      name: platform-namespaces
```

## Version Management

Add a version entry to `kubernetes/platform/versions.env` with a Renovate annotation, then reference via `${variable_name}` in `helm-charts.yaml`. For annotation syntax and datasource selection, see the [versions-renovate skill](../versions-renovate/SKILL.md).

## Debugging Flux

Check status: `kubectl get resourcesets -n flux-system` → `kubectl describe resourceset platform-resources -n flux-system`

Check HelmRelease: `kubectl get helmreleases -A` → `kubectl describe helmrelease <name> -n <namespace>`

Force reconciliation: `flux reconcile helmrelease <name> -n <namespace>` or `flux reconcile kustomization flux-system -n flux-system`

| Symptom | Cause | Solution |
|---------|-------|----------|
| `waiting for dependencies` | Dependency not ready | Check `dependsOn` releases |
| `values key not found` | Missing values file | Add to kustomization.yaml configMapGenerator |
| `chart not found` | Wrong chart name/URL | Verify chart exists in repository |
| `namespace not found` | Namespace not created | Add to namespaces.yaml |
