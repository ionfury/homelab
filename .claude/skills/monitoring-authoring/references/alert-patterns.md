# Alert Patterns Reference

## PromQL Template Functions

Functions available in `summary` and `description` annotations:

| Function | Input | Output | Example |
|----------|-------|--------|---------|
| `humanize` | Number | Human-readable number | `{{ $value \| humanize }}` -> "1.234k" |
| `humanizePercentage` | Float (0-1) | Percentage string | `{{ $value \| humanizePercentage }}` -> "45.6%" |
| `humanizeDuration` | Seconds | Duration string | `{{ $value \| humanizeDuration }}` -> "2h 30m" |
| `printf` | Format string | Formatted value | `{{ printf "%.2f" $value }}` -> "1.23" |

Access alert labels via `{{ $labels.<label_name> }}` and the expression value via `{{ $value }}`.

## Annotation Template

```yaml
annotations:
  summary: "Short title with {{ $labels.relevant_label }}"
  description: >-
    Multi-line description explaining what happened, the impact,
    and what to investigate. Reference threshold values and current
    values using template functions.
  runbook_url: "https://github.com/ionfury/homelab/blob/main/docs/runbooks/<runbook>.md"
```

`runbook_url` is optional but recommended for critical alerts with established recovery procedures.

## Common Alert Patterns

**Target down (availability):**
```yaml
- alert: <Component>Down
  expr: up{job="<job-name>"} == 0
  for: 5m
  labels:
    severity: critical
  annotations:
    summary: "<Component> is down on {{ $labels.instance }}"
```

**Absence detection (component disappeared entirely):**
```yaml
- alert: <Component>Down
  expr: absent(up{job="<job-name>"} == 1)
  for: 5m
  labels:
    severity: critical
  annotations:
    summary: "<Component> is unavailable"
```

**Error rate (ratio):**
```yaml
- alert: <Component>HighErrorRate
  expr: |
    (
      sum(rate(http_requests_total{job="<job>",status=~"5.."}[5m]))
      /
      sum(rate(http_requests_total{job="<job>"}[5m]))
    ) > 0.05
  for: 10m
  labels:
    severity: warning
  annotations:
    summary: "<Component> error rate above 5%"
    description: "Error rate is {{ $value | humanizePercentage }}"
```

**Latency (histogram quantile):**
```yaml
- alert: <Component>HighLatency
  expr: |
    histogram_quantile(0.99,
      sum(rate(http_request_duration_seconds_bucket{job="<job>"}[5m])) by (le)
    ) > 1
  for: 10m
  labels:
    severity: warning
  annotations:
    summary: "<Component> p99 latency above 1s"
    description: "P99 latency is {{ $value | humanizeDuration }}"
```

**Resource pressure (capacity):**
```yaml
- alert: <Component>ResourcePressure
  expr: <resource_used> / <resource_total> > 0.9
  for: 5m
  labels:
    severity: critical
  annotations:
    summary: "<Component> at {{ $value | humanizePercentage }} capacity"
```

**PVC space low:**
```yaml
- alert: <Component>PVCLow
  expr: |
    kubelet_volume_stats_available_bytes{persistentvolumeclaim=~".*<component>.*"}
    /
    kubelet_volume_stats_capacity_bytes{persistentvolumeclaim=~".*<component>.*"}
    < 0.15
  for: 15m
  labels:
    severity: warning
  annotations:
    summary: "PVC {{ $labels.persistentvolumeclaim }} running low"
    description: "{{ $value | humanizePercentage }} free space remaining"
```

## Recording Rule Naming and Examples

Recording rule names follow `level:metric:operations`:

```
loki:request_duration_seconds:p99
loki:requests_total:rate5m
loki:requests_error_rate:ratio5m
```

When to create recording rules:
- Dashboard queries that aggregate across many series
- Queries used by multiple alerts (avoids redundant computation)
- Complex multi-step computations hard to read inline

```yaml
- record: loki:request_duration_seconds:p99
  expr: |
    histogram_quantile(0.99,
      sum(rate(loki_request_duration_seconds_bucket[5m])) by (le, job, namespace)
    )

- record: loki:requests_error_rate:ratio5m
  expr: |
    sum(rate(loki_request_duration_seconds_count{status_code=~"5.."}[5m])) by (job, namespace)
    /
    sum(rate(loki_request_duration_seconds_count[5m])) by (job, namespace)
```

## Existing Alert Files

| File | Component | Alert Count | Subsystem |
|------|-----------|-------------|-----------|
| `monitoring/cilium-alerts.yaml` | Cilium | 14 | Agent, BPF, Policy, Network |
| `monitoring/istio-alerts.yaml` | Istio | ~10 | Control plane, mTLS, Gateway |
| `monitoring/cert-manager-alerts.yaml` | cert-manager | 5 | Expiry, Renewal, Issuance |
| `monitoring/network-policy-alerts.yaml` | Network Policy | 2 | Enforcement escape hatch |
| `monitoring/external-secrets-alerts.yaml` | External Secrets | 3 | Sync, Ready, Store health |
| `monitoring/grafana-alerts.yaml` | Grafana | 4 | Datasource, Errors, Plugins, Down |
| `monitoring/loki-mixin-alerts.yaml` | Loki | ~5 | Requests, Latency, Ingester |
| `monitoring/alloy-alerts.yaml` | Alloy | 3 | Dropped entries, Errors, Lag |
| `monitoring/hardware-monitoring-alerts.yaml` | Hardware | 7 | Temperature, Fans, Disks, Power |
| `dragonfly/prometheus-rules.yaml` | Dragonfly | 2+ | Down, Memory |
| `canary-checker/prometheus-rules.yaml` | canary-checker | 2 | Check failure, High failure rate |

## PrometheusRule Template

```yaml
---
# yaml-language-server: $schema=https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/monitoring.coreos.com/prometheusrule_v1.json
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: <component>-alerts
  labels:
    app.kubernetes.io/name: <component>
    release: kube-prometheus-stack    # REQUIRED - Prometheus selector
spec:
  groups:
    - name: <component>.rules
      rules:
        - alert: AlertName
          expr: <PromQL expression>
          for: 5m
          labels:
            severity: critical        # critical | warning | info
          annotations:
            summary: "Short human-readable summary with {{ $labels.instance }}"
            description: >-
              Detailed explanation. Use {{ $value | humanize }}, {{ $labels.label }}.
```
