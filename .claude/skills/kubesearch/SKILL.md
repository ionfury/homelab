---
name: kubesearch
description: |
  Search kubesearch.dev to research how other homelabs configure Helm charts.

  Use when: (1) Configuring a new Helm release, (2) Looking for configuration examples,
  (3) Comparing approaches across repositories, (4) Needing real-world values.yaml patterns,
  (5) Researching best practices for specific charts, (6) Finding example implementations.

  Triggers: "how do others configure", "show me examples", "helm chart examples",
  "configuration examples", "values.yaml examples", "kubesearch", "homelab examples",
  "how do other homelabs", "real-world config", "chart configuration", "helm values examples",
  "compare helm configs", "best practices for helm"
user-invocable: false
---

# KubeSearch - Homelab Helm Configuration Research

Search kubesearch.dev to find real-world Helm configurations from other homelab repositories.

## Workflow

**Step 1 — Find chart:** `WebFetch https://kubesearch.dev/?search=<chart-name>` → list matching releases with registry paths.

**Step 2 — Get repository links:** Convert registry path to URL format (replace `/` with `-`), then `WebFetch https://kubesearch.dev/hr/<url-path>` → list repositories with direct GitHub links to HelmRelease files.

Examples of the URL conversion:
- `ghcr.io/grafana-helm-charts/grafana` → `ghcr.io-grafana-helm-charts-grafana`
- `charts.longhorn.io/longhorn` → `charts.longhorn.io-longhorn`

**Step 3 — Fetch configs:** Convert GitHub blob URLs to raw URLs, then fetch 3-5 in parallel:
- Blob: `github.com/<owner>/<repo>/blob/<branch>/<path>`
- Raw: `raw.githubusercontent.com/<owner>/<repo>/<branch>/<path>`

**Selection criteria:** recent activity (within 6 months), higher star count, similar chart version, similar infrastructure goals (bare-metal, GitOps, Talos).

## Common Homelab Repositories

| Repository | Focus |
|------------|-------|
| `onedr0p/home-ops` | Flux GitOps, extensive automation |
| `bjw-s/home-ops` | App-template patterns |
| `buroa/k8s-gitops` | Talos + Flux |
| `mirceanton/home-ops` | Well-documented configs |

See [references/output-format.md](references/output-format.md) for the standard output structure when presenting findings.
