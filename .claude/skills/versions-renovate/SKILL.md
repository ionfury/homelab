---
name: versions-renovate
description: |
  Managing platform versions and Renovate annotations in the homelab.

  Use when: (1) Adding a new version entry to versions.env, (2) Configuring Renovate to track a new dependency,
  (3) Debugging why Renovate ignores or mis-detects a version, (4) Understanding annotation syntax for versions.env,
  (5) Adding container image tracking to YAML files, (6) Configuring package rules or grouping in Renovate.

  Triggers: "versions.env", "renovate annotation", "renovate not updating", "add version",
  "renovate ignore", "datasource", "extractVersion", "package rule", "automerge",
  "renovate validate", "dependency tracking", "version management"
user-invocable: false
---

# Versions and Renovate Management

Versions live in `kubernetes/platform/versions.env`. Renovate's custom regex manager in `.github/renovate.json5` parses `# renovate:` annotations on the line above each entry. Flux substitutes `${var}` references into HelmRelease specs at reconcile time.

## Annotation Syntax

```env
# renovate: datasource=<source> depName=<name> [packageName=<pkg>] [extractVersion=<regex>] [registryUrl=<url>] [versioning=<scheme>]
variable_name=<value>
```

**Key ordering is fixed**: `datasource`, `depName`, `packageName`, `extractVersion`, `registryUrl`, `versioning`. Rearranging keys causes Renovate to silently skip the entry.

| Field | Required | Purpose |
|-------|----------|---------|
| `datasource` | Yes | Where Renovate looks (`helm`, `docker`, `github-releases`, `github-tags`) |
| `depName` | Yes | Human-readable name shown in Renovate PRs |
| `packageName` | No | Registry-specific lookup path (OCI registries, GitHub repos) |
| `extractVersion` | No | Regex to transform upstream version (e.g., strip `v` prefix) |
| `registryUrl` | No | HTTP Helm repository URL (not for OCI) |
| `versioning` | No | Version scheme override for non-semver (e.g., `loose`) |

## Datasource Selection

```
HTTP Helm registry    --> datasource=helm + registryUrl=<url>
OCI Helm registry     --> datasource=docker + packageName=<full-path>   (no oci:// prefix)
GitHub release        --> datasource=github-releases + packageName=<org/repo>
GitHub tag            --> datasource=github-tags + packageName=<org/repo>
```

## Examples

```env
# HTTP Helm registry
# renovate: datasource=helm depName=grafana registryUrl=https://grafana.github.io/helm-charts
grafana_version=10.5.15

# OCI Helm registry
# renovate: datasource=docker depName=app-template packageName=ghcr.io/bjw-s-labs/helm/app-template
app_template_version=4.6.2

# GitHub releases (keep v prefix)
# renovate: datasource=github-releases depName=talos packageName=siderolabs/talos
talos_version=v1.12.2

# GitHub tags (strip v prefix with extractVersion)
# renovate: datasource=github-tags depName=kubernetes packageName=kubernetes/kubernetes extractVersion=^v(?<version>.*)$
kubernetes_version=1.35.0

# Strip v from Helm chart releases
# renovate: datasource=helm depName=cert-manager extractVersion=^v(?<version>.*)$ registryUrl=https://charts.jetstack.io
cert_manager_version=1.19.3

# Non-semver versions
# renovate: datasource=docker depName=cloudnative-vectorchord packageName=ghcr.io/tensorchord/cloudnative-vectorchord versioning=loose
vectorchord_version=18.1-1.0.0
```

## YAML Container Image Annotations

For image tags hardcoded in Helm values files (sidecars, init containers):

```yaml
image:
  repository: ghcr.io/kashalls/kromgo
  # renovate: datasource=docker depName=ghcr.io/kashalls/kromgo
  tag: v0.7.5
```

```yaml
initContainers:
  # renovate: datasource=docker depName=ghcr.io/home-operations/postgres-init
  image: ghcr.io/home-operations/postgres-init:18
```

## Package Rules

Add to `.github/renovate.json5` to group related charts or block automerge:

```json5
{
  "matchDepNames": ["my-chart", "related-chart"],
  "groupName": "my stack"
}
```

`matchDepNames` values must match the `depName` in the annotation. By default, minor/patch updates automerge after 3 days (`.renovate/automerge.json5`). Infrastructure-critical groups (talos, kubernetes, cilium, gateway-api, flux) have automerge disabled.

After changes, run `task renovate:validate`.

## Debugging

| Symptom | Cause | Fix |
|---------|---------|-----|
| Silently ignored | Wrong key order | Follow exact order above |
| Can't find package | `oci://` prefix in packageName | Remove `oci://` prefix |
| Version has unwanted `v` | Missing `extractVersion` | Add `extractVersion=^v(?<version>.*)$` |
| Can't find OCI chart | `datasource=helm` for OCI | Use `datasource=docker` |
| Skips non-semver | Missing `versioning=loose` | Add `versioning=loose` |
| Regex doesn't match | Annotation not on line above | Must be immediately above `key=value` |

Also check: dependency dashboard in the Renovate GitHub issue, `ignorePaths` in `renovate.json5`.
