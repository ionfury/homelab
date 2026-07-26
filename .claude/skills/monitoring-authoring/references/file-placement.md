# File Placement Reference

## Placement by Scope

| Scope | Path | When to Use |
|-------|------|-------------|
| Platform-wide alerts/monitors | `kubernetes/platform/config/monitoring/` | Alerts for platform components (Cilium, Istio, cert-manager, etc.) |
| Subsystem-specific alerts | `kubernetes/platform/config/<subsystem>/` | Alerts bundled with the subsystem they monitor (e.g., `dragonfly/prometheus-rules.yaml`) |
| Cluster-specific silences | `kubernetes/clusters/<cluster>/config/silences/` | Silences for known issues on specific clusters |
| Cluster-specific alerts | `kubernetes/clusters/<cluster>/config/` | Alerts that only apply to a specific cluster |
| Canary health checks | `kubernetes/platform/config/canary-checker/` | Platform-wide synthetic checks |

## File Naming Conventions

| Pattern | Example | When |
|---------|---------|------|
| `<component>-alerts.yaml` | `cilium-alerts.yaml`, `grafana-alerts.yaml` | PrometheusRule files |
| `<component>-recording-rules.yaml` | `loki-mixin-recording-rules.yaml` | Recording rules |
| `<component>-servicemonitors.yaml` | `istio-servicemonitors.yaml` | ServiceMonitor/PodMonitor files |
| `<component>-canary.yaml` | `alertmanager-canary.yaml` | Canary health checks |
| `<component>-route.yaml` | `grafana-route.yaml` | HTTPRoute for gateway access |
| `<component>-secret.yaml` | `discord-secret.yaml` | ExternalSecrets for monitoring |
| `<component>-scrape.yaml` | `hardware-monitoring-scrape.yaml` | ScrapeConfig resources |

## Registration

After creating a file in `config/monitoring/`, add it to the kustomization:

```yaml
# kubernetes/platform/config/monitoring/kustomization.yaml
resources:
  - ...existing resources...
  - my-new-alerts.yaml    # Add alphabetically by component
```

For subsystem-specific files, add to that subsystem's `kustomization.yaml` instead.

## Silence Placement

```
kubernetes/clusters/<cluster>/config/silences/
  ├── kustomization.yaml
  └── <descriptive-name>.yaml
```

### Adding a Silence

create `config/silences/` if absent → add Silence YAML → create/update `config/silences/kustomization.yaml` → reference `silences` in `config/kustomization.yaml`
