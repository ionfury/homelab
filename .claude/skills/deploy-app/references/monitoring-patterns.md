# Monitoring Patterns for Application Deployment

Templates and best practices for ServiceMonitor, PrometheusRule, Canary, and Grafana dashboards.

---

## ServiceMonitor

Most Helm charts support ServiceMonitor creation via values. Enable it in the chart values:

### Via Helm Values (Preferred)

```yaml
# kubernetes/platform/charts/<app-name>.yaml
serviceMonitor:
  enabled: true
  interval: 30s
  scrapeTimeout: 10s
  # Optional: additional labels for Prometheus selector
  labels: {}
```

Alternative patterns (check chart docs):
```yaml
metrics:
  enabled: true
  serviceMonitor:
    enabled: true

# or
prometheus:
  serviceMonitor:
    enabled: true
```

### Manual ServiceMonitor (if chart doesn't support)

```yaml
# kubernetes/platform/config/<app-name>/servicemonitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: <app-name>
  labels:
    release: kube-prometheus-stack  # Must match Prometheus selector
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: <app-name>
  namespaceSelector:
    matchNames:
      - <namespace>
  endpoints:
    - port: metrics  # Must match service port name
      interval: 30s
      scrapeTimeout: 10s
      path: /metrics
```

### Verify ServiceMonitor Discovery

```bash
# After deployment, verify Prometheus is scraping
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090 &

# Check targets
curl -s "http://localhost:9090/api/v1/targets" | \
  jq '.data.activeTargets[] | select(.labels.job | contains("<app-name>"))'
```

---

## PrometheusRule (Custom Alerts)

Only create custom alerts if the chart doesn't include its own. Most kube-prometheus-stack compatible charts include sensible defaults.

### Basic Application Alert

```yaml
# kubernetes/platform/config/<app-name>/prometheus-rules.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: <app-name>-alerts
  labels:
    release: kube-prometheus-stack  # Must match Prometheus selector
spec:
  groups:
    - name: <app-name>.rules
      rules:
        # Application Down Alert
        - alert: <AppName>Down
          expr: up{job="<app-name>"} == 0
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "<app-name> is down"
            description: "{{ $labels.instance }} has been down for more than 5 minutes."
            runbook_url: "https://docs.example.com/runbooks/<app-name>"
```

### Request Latency Alert

```yaml
        # High Latency Alert
        - alert: <AppName>HighLatency
          expr: |
            histogram_quantile(0.99,
              sum(rate(http_request_duration_seconds_bucket{job="<app-name>"}[5m])) by (le)
            ) > 1
          for: 10m
          labels:
            severity: warning
          annotations:
            summary: "<app-name> experiencing high latency"
            description: "P99 latency is {{ $value | humanizeDuration }} (threshold: 1s)"
```

### Error Rate Alert

```yaml
        # High Error Rate Alert
        - alert: <AppName>HighErrorRate
          expr: |
            sum(rate(http_requests_total{job="<app-name>",status=~"5.."}[5m]))
            /
            sum(rate(http_requests_total{job="<app-name>"}[5m]))
            > 0.05
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "<app-name> high error rate"
            description: "Error rate is {{ $value | humanizePercentage }}"
```

### PVC Space Alert

```yaml
        # Persistent Volume Running Low
        - alert: <AppName>PVCLow
          expr: |
            kubelet_volume_stats_available_bytes{persistentvolumeclaim=~".*<app-name>.*"}
            /
            kubelet_volume_stats_capacity_bytes{persistentvolumeclaim=~".*<app-name>.*"}
            < 0.15
          for: 15m
          labels:
            severity: warning
          annotations:
            summary: "<app-name> PVC running low on space"
            description: "PVC {{ $labels.persistentvolumeclaim }} has {{ $value | humanizePercentage }} free"
```

---

## Canary Health Checks

Canary resources provide synthetic monitoring via Flanksource canary-checker.

### HTTP Health Check

```yaml
# kubernetes/platform/config/<app-name>/canary.yaml
apiVersion: canaries.flanksource.com/v1
kind: Canary
metadata:
  name: http-check-<app-name>
spec:
  schedule: "@every 1m"
  http:
    - name: <app-name>-health
      url: https://<app-name>.${internal_domain}/health
      responseCodes: [200]
      maxSSLExpiry: 7
      # Optional: response body check
      responseContent:
        content: '"status":"healthy"'
```

### HTTP with Authentication

```yaml
apiVersion: canaries.flanksource.com/v1
kind: Canary
metadata:
  name: http-check-<app-name>
spec:
  schedule: "@every 1m"
  http:
    - name: <app-name>-health
      url: https://<app-name>.${internal_domain}/api/health
      responseCodes: [200]
      headers:
        - name: Authorization
          valueFrom:
            secretKeyRef:
              name: <app-name>-canary-token
              key: token
```

### TCP Port Check

```yaml
apiVersion: canaries.flanksource.com/v1
kind: Canary
metadata:
  name: tcp-check-<app-name>
spec:
  schedule: "@every 1m"
  tcp:
    - name: <app-name>-port
      host: <app-name>.<namespace>.svc.cluster.local
      port: 8080
      timeout: 5000
```

### Multiple Endpoints

```yaml
apiVersion: canaries.flanksource.com/v1
kind: Canary
metadata:
  name: http-check-<app-name>
spec:
  schedule: "@every 1m"
  http:
    - name: <app-name>-health
      url: https://<app-name>.${internal_domain}/health
      responseCodes: [200]
    - name: <app-name>-ready
      url: https://<app-name>.${internal_domain}/ready
      responseCodes: [200]
    - name: <app-name>-metrics
      url: http://<app-name>.<namespace>.svc.cluster.local:9090/metrics
      responseCodes: [200]
```

---

## Grafana Dashboards

### Strategy 1: Search grafana.com (Recommended)

1. Search for community dashboards: https://grafana.com/grafana/dashboards/?search=<app>
2. Note the dashboard ID (gnetId)
3. Add to Grafana values:

```yaml
# kubernetes/platform/charts/grafana.yaml (or kube-prometheus-stack.yaml)
grafana:
  dashboards:
    default:
      <app-name>:
        gnetId: 12345
        revision: 1
        datasource: Prometheus
```

### Strategy 2: ConfigMap Dashboard

If no community dashboard exists or customization needed:

```yaml
# kubernetes/platform/config/<app-name>/dashboard.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-dashboard-<app-name>
  labels:
    grafana_dashboard: "true"
  annotations:
    grafana_folder: "Applications"
data:
  <app-name>.json: |
    {
      "annotations": { "list": [] },
      "editable": true,
      "fiscalYearStartMonth": 0,
      "graphTooltip": 0,
      "id": null,
      "links": [],
      "liveNow": false,
      "panels": [
        {
          "datasource": { "type": "prometheus", "uid": "prometheus" },
          "fieldConfig": {
            "defaults": { "unit": "short" }
          },
          "gridPos": { "h": 8, "w": 12, "x": 0, "y": 0 },
          "id": 1,
          "options": {},
          "targets": [
            {
              "expr": "up{job=\"<app-name>\"}",
              "legendFormat": "{{ instance }}"
            }
          ],
          "title": "<app-name> Up Status",
          "type": "stat"
        }
      ],
      "schemaVersion": 38,
      "style": "dark",
      "tags": ["<app-name>"],
      "templating": { "list": [] },
      "time": { "from": "now-1h", "to": "now" },
      "title": "<App Name>",
      "uid": "<app-name>-dashboard"
    }
```

### Strategy 3: Chart-Included Dashboard

Many charts include dashboards that can be enabled:

```yaml
# kubernetes/platform/charts/<app-name>.yaml
grafana:
  enabled: true
  # or
dashboards:
  enabled: true
  # or
metrics:
  dashboards:
    enabled: true
```

---

## Quick Reference: Common Metrics

| App Type | Common Metrics |
|----------|---------------|
| HTTP Service | `http_requests_total`, `http_request_duration_seconds`, `http_request_size_bytes` |
| Database | `<db>_up`, `<db>_connections`, `<db>_queries_total`, `<db>_query_duration_seconds` |
| Queue | `<queue>_messages_total`, `<queue>_consumers`, `<queue>_lag` |
| Cache | `<cache>_hits_total`, `<cache>_misses_total`, `<cache>_memory_bytes` |

---

## Monitoring Checklist

Before marking deployment complete, verify:

- [ ] ServiceMonitor created and targets discovered in Prometheus
- [ ] No new alerts firing (check baseline comparison)
- [ ] Grafana dashboard accessible (if added)
- [ ] Canary health checks passing (if created)
- [ ] Custom PrometheusRules validated against real metrics
