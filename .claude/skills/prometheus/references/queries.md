# Homelab PromQL Query Reference

## Table of Contents
- [Cluster Overview](#cluster-overview)
- [Node Metrics](#node-metrics)
- [Pod & Container Metrics](#pod--container-metrics)
- [Storage (Longhorn)](#storage-longhorn)
- [Networking (Cilium)](#networking-cilium)
- [Database (CloudNative-PG)](#database-cloudnative-pg)
- [Flux GitOps](#flux-gitops)
- [Alert Queries](#alert-queries)

---

## Cluster Overview

```promql
# Cluster uptime (days since oldest node boot)
round((time() - min(node_boot_time_seconds)) / 86400)

# Node count
count(kube_node_info)

# Pod count
count(kube_pod_info)

# Kubernetes version
kubernetes_build_info{service="kubernetes"}
```

## Node Metrics

```promql
# CPU usage (%)
avg(1 - rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100

# CPU usage per node
(1 - avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m]))) * 100

# Memory usage (%)
(1 - sum(node_memory_MemAvailable_bytes) / sum(node_memory_MemTotal_bytes)) * 100

# Memory usage per node
(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100

# Disk usage (%)
(1 - node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100

# Network receive rate (bytes/sec)
rate(node_network_receive_bytes_total{device!~"lo|cni.*|veth.*"}[5m])

# Network transmit rate (bytes/sec)
rate(node_network_transmit_bytes_total{device!~"lo|cni.*|veth.*"}[5m])

# Load average (1m)
node_load1

# System uptime per node
(time() - node_boot_time_seconds) / 86400
```

## Pod & Container Metrics

```promql
# Running pods by namespace
count by(namespace) (kube_pod_status_phase{phase="Running"})

# Non-running pods (problem detection)
kube_pod_status_phase{phase!~"Running|Succeeded"} == 1

# Container restarts in last hour
increase(kube_pod_container_status_restarts_total[1h]) > 0

# OOMKilled containers
kube_pod_container_status_last_terminated_reason{reason="OOMKilled"} == 1

# Container CPU usage
rate(container_cpu_usage_seconds_total{container!=""}[5m])

# Container memory usage
container_memory_working_set_bytes{container!=""}

# Pods pending for >5 minutes
time() - kube_pod_created > 300 and kube_pod_status_phase{phase="Pending"} == 1

# Top 10 CPU-consuming pods
topk(10, sum by(pod, namespace) (rate(container_cpu_usage_seconds_total{container!=""}[5m])))

# Top 10 memory-consuming pods
topk(10, sum by(pod, namespace) (container_memory_working_set_bytes{container!=""}))
```

## Storage (Longhorn)

```promql
# Volume capacity (bytes)
longhorn_volume_capacity_bytes

# Volume actual size (bytes used)
longhorn_volume_actual_size_bytes

# Volume usage percentage
(longhorn_volume_actual_size_bytes / longhorn_volume_capacity_bytes) * 100

# Degraded volumes
longhorn_volume_robustness{robustness="degraded"}

# Unhealthy volumes
longhorn_volume_robustness{robustness!="healthy"}

# Volume state (attached, detached, etc)
longhorn_volume_state

# Replica count per volume
count by(volume) (longhorn_replica_mode)

# Node storage utilization
longhorn_node_storage_usage_bytes / longhorn_node_storage_capacity_bytes * 100
```

## Networking (Cilium)

```promql
# Cilium agent health
cilium_agent_api_process_time_seconds_count

# Dropped packets
rate(cilium_drop_count_total[5m])

# Policy enforcement
cilium_policy_enforcement_enabled

# Endpoint count
cilium_endpoint_count

# BPF map pressure
cilium_bpf_map_pressure
```

## Database (CloudNative-PG)

```promql
# Cluster health (1 = healthy)
cnpg_pg_replication_is_replica == 0

# Replication lag (seconds)
cnpg_pg_replication_lag

# Connection pool utilization
cnpg_backends_total / cnpg_pg_settings_setting{name="max_connections"} * 100

# Database size (bytes)
cnpg_pg_database_size_bytes

# Transaction rate
rate(cnpg_pg_stat_database_xact_commit[5m])

# WAL generation rate
rate(cnpg_pg_stat_archiver_archived_count[5m])

# Active connections
cnpg_backends_total
```

## Flux GitOps

```promql
# Flux reconciliation status (0 = healthy)
gotk_reconcile_condition{type="Ready", status="True"} == 0

# Failed reconciliations
gotk_reconcile_condition{type="Ready", status="False"} == 1

# Reconciliation duration
gotk_reconcile_duration_seconds_bucket

# Suspended resources
gotk_suspend_status == 1
```

## Alert Queries

These are the same expressions used by configured Prometheus alerts:

```promql
# OOMKilled detection (from kube-prometheus-stack values)
(kube_pod_container_status_restarts_total - kube_pod_container_status_restarts_total offset 10m >= 1)
and ignoring (reason) min_over_time(kube_pod_container_status_last_terminated_reason{reason="OOMKilled"}[10m]) == 1

# API server client cert expiration (7 days warning)
apiserver_client_certificate_expiration_seconds_count{job="apiserver"} > 0
and on() (apiserver_client_certificate_expiration_seconds_bucket{le="604800", job="apiserver"} > 0)

# CloudNative-PG cluster not healthy
cnpg_pg_replication_is_replica == 0

# CloudNative-PG high connections (>80%)
sum by(cluster) (cnpg_backends_total)
/ max by(cluster) (cnpg_pg_settings_setting{name="max_connections"}) > 0.8
```

---

## Useful Label Filters

Common labels in this cluster:

| Label | Values | Description |
|-------|--------|-------------|
| `job` | `node-exporter`, `kube-state-metrics`, `apiserver` | Scrape target |
| `namespace` | `monitoring`, `database`, `longhorn-system` | Kubernetes namespace |
| `cluster` | `dev`, `integration`, `live` | Cluster name (external label) |
| `prometheus_source` | `${cluster_name}` | Cluster identifier |

## Rate vs Increase

- **rate()**: Per-second average (use for gauges over time)
- **increase()**: Total increase over period (use for counting events)

```promql
# CPU rate (continuous metric)
rate(node_cpu_seconds_total[5m])

# Restart count (discrete events)
increase(kube_pod_container_status_restarts_total[1h])
```
