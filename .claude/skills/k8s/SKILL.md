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
user-invocable: false
---

# ACCESSING CLUSTERS

The available clusters are `dev`, `integration`, and `live`.  Use the coresponding kube context for access.

# Common kubectl Patterns

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
| `Ready: True` | Reconciled and healthy | None |
| `Ready: False` | Failed to reconcile | Check the message/reason |
| `Stalled: True` | Stopped retrying after repeated failures | Suspend/resume to reset (see `sre` skill) |
| `Suspended: True` | Intentionally paused | Resume: `flux resume <type> <name>` |
| `Reconciling` | Actively being applied | Wait for completion |

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
GOOD: Use `kubectl get helmrelease -A` — Flux manages releases via CRDs, not Helm CLI
