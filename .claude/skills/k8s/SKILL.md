---
name: k8s
description: |
  Kubernetes operational knowledge for accessing clusters, running kubectl, understanding Flux status,
  and navigating the homelab Kubernetes environment.

  Use when: (1) Accessing a cluster or checking connectivity, (2) Running kubectl commands or checking resource status,
  (3) Checking Flux reconciliation status or triggering reconciliation, (4) Finding internal service URLs,
  (5) Understanding cluster layout or resource types, (6) Researching unfamiliar Helm charts or services.

  Triggers: "kubectl", "kubeconfig", "flux get", "flux reconcile", "flux status", "cluster access",
  "internal URL", "service URL", "prometheus URL", "grafana URL", "helm release status",
  "check flux", "which cluster", "how to access", "port-forward"
user_invocable: false
---

# ACCESSING CLUSTERS

**CRITICAL:** Always prefix kubectl/flux commands with inline KUBECONFIG assignment. Do NOT use `export` or `&&` - the variable must be set in the same command:

```bash
# CORRECT - inline assignment
KUBECONFIG=~/.kube/<cluster>.yaml kubectl get pods

# WRONG - export with && breaks in some shell contexts
export KUBECONFIG=~/.kube/<cluster>.yaml && kubectl get pods
```

## Cluster Context

**CRITICAL:** Always confirm cluster before running commands.

| Cluster | Purpose | Kubeconfig |
|---------|---------|------------|
| `dev` | Manual testing | `~/.kube/dev.yaml` |
| `integration` | Automated testing | `~/.kube/integration.yaml` |
| `live` | Production | `~/.kube/live.yaml` |

```bash
KUBECONFIG=~/.kube/<cluster>.yaml kubectl <command>
```

## Accessing Internal Services via DNS (Preferred)

Platform services are exposed through the internal ingress gateway over HTTPS. **Always use DNS-based access instead of port-forwarding** when querying Prometheus, Grafana, Alertmanager, and other internal services.

| Service | Live | Integration | Dev |
|---------|------|-------------|-----|
| Prometheus | `https://prometheus.internal.tomnowak.work` | `https://prometheus.internal.integration.tomnowak.work` | `https://prometheus.internal.dev.tomnowak.work` |
| Grafana | `https://grafana.internal.tomnowak.work` | `https://grafana.internal.integration.tomnowak.work` | `https://grafana.internal.dev.tomnowak.work` |
| Alertmanager | `https://alertmanager.internal.tomnowak.work` | `https://alertmanager.internal.integration.tomnowak.work` | `https://alertmanager.internal.dev.tomnowak.work` |
| Hubble UI | `https://hubble.internal.tomnowak.work` | `https://hubble.internal.integration.tomnowak.work` | `https://hubble.internal.dev.tomnowak.work` |
| Longhorn UI | `https://longhorn.internal.tomnowak.work` | `https://longhorn.internal.integration.tomnowak.work` | `https://longhorn.internal.dev.tomnowak.work` |
| Garage Admin | `https://garage.internal.tomnowak.work` | `https://garage.internal.integration.tomnowak.work` | `https://garage.internal.dev.tomnowak.work` |

**Domain pattern:** `<service>.internal.<cluster-suffix>.tomnowak.work`
- live: `internal.tomnowak.work`
- integration: `internal.integration.tomnowak.work`
- dev: `internal.dev.tomnowak.work`

**Usage with curl (use `-k` for self-signed TLS):**

```bash
# Query Prometheus API
curl -sk "https://prometheus.internal.tomnowak.work/api/v1/query?query=up" | jq '.data.result'

# Check firing alerts
curl -sk "https://prometheus.internal.tomnowak.work/api/v1/alerts" | jq '.data.alerts[] | select(.state == "firing")'

# Query Alertmanager
curl -sk "https://alertmanager.internal.tomnowak.work/api/v2/alerts" | jq .
```

**Using the helper scripts with internal DNS:**

```bash
# Prometheus (live cluster)
export PROMETHEUS_URL=https://prometheus.internal.tomnowak.work
.claude/skills/prometheus/scripts/promql.sh alerts --firing

# Loki (no HTTPRoute - requires port-forward, see fallback below)
KUBECONFIG=~/.kube/<cluster>.yaml kubectl port-forward -n monitoring svc/loki-headless 3100:3100 &
export LOKI_URL=http://localhost:3100
.claude/skills/loki/scripts/logql.sh tail '{namespace="monitoring"}' --since 15m
```

**Note:** Loki does not have an HTTPRoute on the internal gateway. Use port-forward for Loki access.

### Fallback: Port-Forward Access

Use port-forwarding only when DNS-based access is unavailable (e.g., network issues, local development without VPN):

```bash
KUBECONFIG=~/.kube/<cluster>.yaml kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090 &
KUBECONFIG=~/.kube/<cluster>.yaml kubectl port-forward -n monitoring svc/loki-headless 3100:3100 &
```

# Common kubectl Patterns

Read-only commands used during daily operations and investigations:

| Command | Purpose |
|---------|---------|
| `kubectl get pods -n <ns>` | List pods in a namespace |
| `kubectl get pods -A` | List pods across all namespaces |
| `kubectl describe pod <pod> -n <ns>` | Detailed pod info with events |
| `kubectl logs <pod> -n <ns> --tail=100` | Recent logs from a pod |
| `kubectl logs <pod> -n <ns> --previous` | Logs from previous container instance |
| `kubectl get events -n <ns> --sort-by='.lastTimestamp'` | Recent events timeline |
| `kubectl top pods -n <ns>` | CPU/memory usage per pod |
| `kubectl top nodes` | CPU/memory usage per node |
| `kubectl get ns <ns> --show-labels` | Namespace labels (network policy profiles) |
| `kubectl explain <resource>` | API schema reference for a resource type |

# Flux GitOps Commands

## Status and Reconciliation

```bash
# Check status
KUBECONFIG=~/.kube/<cluster>.yaml flux get all
KUBECONFIG=~/.kube/<cluster>.yaml flux get kustomizations
KUBECONFIG=~/.kube/<cluster>.yaml flux get helmreleases -A

# Trigger reconciliation
KUBECONFIG=~/.kube/<cluster>.yaml flux reconcile source git flux-system
KUBECONFIG=~/.kube/<cluster>.yaml flux reconcile kustomization <name>
KUBECONFIG=~/.kube/<cluster>.yaml flux reconcile helmrelease <name> -n <namespace>
```

## Flux Status Interpretation

| Status | Meaning | Action |
|--------|---------|--------|
| `Ready: True` | Resource is reconciled and healthy | None - operating normally |
| `Ready: False` | Resource failed to reconcile | Check the message/reason for details |
| `Stalled: True` | Resource has stopped retrying after repeated failures | Suspend/resume to reset (see `sre` skill) |
| `Suspended: True` | Resource is intentionally paused | Resume when ready: `flux resume <type> <name>` |
| `Reconciling` | Resource is actively being applied | Wait for completion |

# Researching Unfamiliar Services

When investigating unknown services, spawn a haiku agent to research documentation:

```
Task tool:
- subagent_type: "general-purpose"
- model: "haiku"
- prompt: "Research [service] troubleshooting docs. Focus on:
  1. Common failure modes
  2. Health indicators
  3. Configuration gotchas
  Start with: [docs-url]"
```

**Chart URL to Docs mapping:**
| Chart Source | Documentation |
|--------------|---------------|
| `charts.jetstack.io` | cert-manager.io/docs |
| `charts.longhorn.io` | longhorn.io/docs |
| `grafana.github.io` | grafana.com/docs |
| `prometheus-community.github.io` | prometheus.io/docs |

# Common Confusions

BAD: Use `helm list` to check Helm release status
GOOD: Use `kubectl get helmrelease -A` - Flux manages releases via CRDs, not Helm CLI

## Keywords

kubernetes, kubectl, kubeconfig, flux, flux status, cluster access, internal URL, service URL, port-forward, helm release, gitops, reconciliation
