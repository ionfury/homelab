---
name: prometheus
description: Query Prometheus API for cluster metrics, alerts, and observability data. Use when investigating cluster health, performance issues, resource utilization, or alert status. Triggers on questions like "what's the CPU usage", "show me firing alerts", "check memory pressure", "query prometheus for", or any PromQL-related requests.
---

# Prometheus Querying

## Setup

Prometheus runs in-cluster. Establish access via port-forward:

```bash
KUBECONFIG=~/.kube/<cluster>.yaml kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090
```

**Clusters**: `dev`, `integration`, `live`

## Quick Queries

Use the bundled script at `scripts/promql.sh`:

```bash
# Set URL (default: localhost:9090)
export PROMETHEUS_URL=http://localhost:9090

# Instant query
./scripts/promql.sh query 'up'

# Range query (last hour, 15s resolution)
./scripts/promql.sh range 'node_cpu_seconds_total' --start 1h --step 15s

# Firing alerts only
./scripts/promql.sh alerts --firing

# All alert rules
./scripts/promql.sh rules

# Find metrics by label
./scripts/promql.sh series '{job="node-exporter"}'

# Health check
./scripts/promql.sh health
```

## Common Operations

### Check Cluster Health

```bash
# CPU usage %
./scripts/promql.sh query 'avg(1 - rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100'

# Memory usage %
./scripts/promql.sh query '(1 - sum(node_memory_MemAvailable_bytes) / sum(node_memory_MemTotal_bytes)) * 100'

# Problem pods
./scripts/promql.sh query 'kube_pod_status_phase{phase!~"Running|Succeeded"} == 1'

# Container restarts (last hour)
./scripts/promql.sh query 'increase(kube_pod_container_status_restarts_total[1h]) > 0'
```

### Check Alerts

```bash
# All firing alerts
./scripts/promql.sh alerts --firing

# Full alert details
./scripts/promql.sh alerts --verbose
```

### Direct curl (alternative)

```bash
# Instant query
curl -s "http://localhost:9090/api/v1/query?query=up" | jq '.data.result'

# Alerts
curl -s "http://localhost:9090/api/v1/alerts" | jq '.data.alerts'
```

## Reference

For homelab-specific PromQL queries (Longhorn, CloudNative-PG, Cilium, etc.), see [references/queries.md](references/queries.md).

## Prometheus Details

| Property | Value |
|----------|-------|
| Namespace | `monitoring` |
| Service | `prometheus-operated:9090` |
| Retention | 14 days / 50GB |
| External label | `prometheus_source: ${cluster_name}` |
