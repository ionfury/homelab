# Homelab LogQL Query Reference

## Table of Contents
- [Basic Log Queries](#basic-log-queries)
- [Error Investigation](#error-investigation)
- [Kubernetes Events](#kubernetes-events)
- [Platform Services](#platform-services)
- [Database (CloudNative-PG)](#database-cloudnative-pg)
- [GitOps (Flux)](#gitops-flux)
- [Networking (Cilium)](#networking-cilium)
- [Log Metrics](#log-metrics)
- [Advanced Patterns](#advanced-patterns)
- [Label Reference](#label-reference)

---

## Basic Log Queries

```logql
# All logs from a namespace
{namespace="monitoring"}

# Filter by pod name
{namespace="monitoring", pod=~"prometheus-.*"}

# Filter by container
{namespace="monitoring", container="prometheus"}

# Text match (contains)
{namespace="monitoring"} |= "error"

# Negative match (exclude)
{namespace="monitoring"} != "healthcheck"

# Regex match
{namespace="monitoring"} |~ "level=(error|warn)"

# Negative regex
{namespace="monitoring"} !~ "GET /health"

# Chained filters
{namespace="database"} |= "error" != "context canceled" != "healthcheck"
```

## Error Investigation

```logql
# Case-insensitive error search
{namespace="database"} |~ "(?i)error|fail|panic|fatal"

# Stack traces (multi-word match)
{namespace="database"} |~ "(?i)exception|traceback|stack trace"

# OOMKilled context - check container logs before kill
{namespace="database", container="postgres"} |~ "(?i)out of memory|oom|memory allocation"

# Crash loop debugging - recent restarts
{namespace="database"} |= "error" | json | level="error"

# HTTP 5xx errors
{namespace="monitoring"} |~ "HTTP/[12].* [5][0-9]{2}"

# Timeout patterns
{namespace="monitoring"} |~ "(?i)timeout|deadline exceeded|context deadline"
```

## Kubernetes Events

Events are shipped to Loki via Alloy's `loki.source.kubernetes_events`.

```logql
# All warning events
{job="integrations/kubernetes/eventhandler"} |= "Warning"

# Events for a namespace
{job="integrations/kubernetes/eventhandler", namespace="database"}

# Scheduling failures
{job="integrations/kubernetes/eventhandler"} |~ "FailedScheduling|Unschedulable"

# Image pull issues
{job="integrations/kubernetes/eventhandler"} |~ "(?i)pull|image|ErrImagePull|ImagePullBackOff"

# Volume events
{job="integrations/kubernetes/eventhandler"} |~ "(?i)volume|attach|mount|pvc"

# Node events (cordoning, draining, not ready)
{job="integrations/kubernetes/eventhandler"} |~ "NodeNotReady|Cordon|Drain|Taint"

# Parse event fields with JSON
{job="integrations/kubernetes/eventhandler"} | json | reason="BackOff"
```

## Platform Services

### Prometheus & Grafana

```logql
# Prometheus errors
{namespace="monitoring", container="prometheus"} |= "err"

# Prometheus config reload
{namespace="monitoring", container="prometheus"} |= "reload"

# Grafana errors
{namespace="monitoring", container="grafana"} |~ "level=(error|eror)"
```

### Cert-Manager

```logql
# Certificate issuance
{namespace="cert-manager"} |~ "(?i)certificate|issue|renew"

# Certificate errors
{namespace="cert-manager"} |~ "(?i)error|fail" != "no error"
```

### External Secrets

```logql
# Secret sync status
{namespace="external-secrets"} |~ "(?i)sync|reconcil"

# External secret errors
{namespace="external-secrets"} |~ "(?i)error|fail"
```

### Alloy (Grafana Agent)

```logql
# Alloy errors
{namespace="monitoring", container="alloy"} |~ "level=error"

# Alloy target discovery
{namespace="monitoring", container="alloy"} |= "target"
```

## Database (CloudNative-PG)

```logql
# Postgres errors
{namespace="database", container="postgres"} |~ "(?i)ERROR|FATAL|PANIC"

# Slow queries (if log_min_duration_statement is set)
{namespace="database", container="postgres"} |= "duration:"

# Connection events
{namespace="database", container="postgres"} |~ "(?i)connection|disconnect|authentication"

# WAL activity
{namespace="database", container="postgres"} |~ "(?i)WAL|wal_level|archive"

# Replication status
{namespace="database", container="postgres"} |~ "(?i)replica|replication|standby|primary"

# CNPG operator logs
{namespace="database", container="manager"} |~ "(?i)error|reconcil|failover|switchover"
```

## GitOps (Flux)

```logql
# All Flux controller errors
{namespace="flux-system"} |~ "(?i)error|fail"

# Source controller (git/OCI fetch issues)
{namespace="flux-system", container="manager", pod=~"source-controller-.*"} |~ "(?i)error|reconcil"

# Kustomize controller (apply issues)
{namespace="flux-system", container="manager", pod=~"kustomize-controller-.*"} |~ "(?i)error|reconcil"

# Helm controller
{namespace="flux-system", container="manager", pod=~"helm-controller-.*"} |~ "(?i)error|reconcil|upgrade|install"

# Reconciliation failures
{namespace="flux-system"} |= "Reconciliation failed"

# Dependency not ready
{namespace="flux-system"} |= "dependency"
```

## Networking (Cilium)

```logql
# Cilium agent errors
{namespace="kube-system", container="cilium-agent"} |~ "level=(error|warning)"

# Policy verdicts
{namespace="kube-system", container="cilium-agent"} |= "verdict"

# Policy drops
{namespace="kube-system", container="cilium-agent"} |= "Policy denied"

# Endpoint events
{namespace="kube-system", container="cilium-agent"} |~ "(?i)endpoint|regenerat"

# Cilium operator
{namespace="kube-system", container="cilium-operator"} |~ "level=(error|warning)"
```

## Log Metrics

LogQL supports metric queries that aggregate log data into numeric values.

```logql
# Error rate per namespace (errors/sec)
sum by(namespace) (rate({namespace=~".+"} |= "error" [5m]))

# Log line count over time per namespace
sum by(namespace) (count_over_time({namespace=~".+"}[5m]))

# Log volume (bytes/sec) per namespace
sum by(namespace) (bytes_rate({namespace=~".+"}[5m]))

# Top 5 noisiest pods
topk(5, sum by(pod) (rate({namespace=~".+"}[5m])))

# Top 5 error-producing namespaces
topk(5, sum by(namespace) (rate({namespace=~".+"} |= "error" [5m])))

# Flux reconciliation failure rate
rate({namespace="flux-system"} |= "Reconciliation failed" [15m])

# Postgres error rate
rate({namespace="database", container="postgres"} |~ "ERROR|FATAL" [5m])
```

## Advanced Patterns

### JSON Log Parsing

```logql
# Parse JSON and filter by field
{namespace="monitoring"} | json | level="error"

# Extract specific fields
{namespace="monitoring"} | json | line_format "{{.level}} {{.msg}}"

# Filter by parsed numeric value
{namespace="monitoring"} | json | duration > 5s
```

### Logfmt Parsing

```logql
# Parse logfmt (key=value) format
{namespace="monitoring"} | logfmt | level="error"

# Extract and filter
{namespace="monitoring"} | logfmt | status >= 500
```

### Label Extraction with Regex

```logql
# Extract HTTP status code
{namespace="monitoring"} | regexp "status=(?P<status>\\d+)" | status >= 500

# Extract duration
{namespace="monitoring"} | regexp "duration=(?P<duration>[\\d.]+)s" | unwrap duration | duration > 5
```

### Unwrap for Numeric Aggregation

```logql
# Average request duration from parsed logs
avg_over_time({namespace="monitoring"} | logfmt | unwrap duration [5m])

# 99th percentile of response size
quantile_over_time(0.99, {namespace="monitoring"} | json | unwrap bytes [5m])
```

---

## Label Reference

Common labels available in this cluster:

| Label | Example Values | Description |
|-------|---------------|-------------|
| `namespace` | `monitoring`, `database`, `flux-system` | Kubernetes namespace |
| `pod` | `prometheus-kps-0`, `loki-0` | Pod name |
| `container` | `prometheus`, `manager`, `postgres` | Container name |
| `job` | `monitoring/alloy`, `integrations/kubernetes/eventhandler` | Scrape job |
| `node_name` | `k8s-1`, `k8s-2` | Kubernetes node |
| `stream` | `stdout`, `stderr` | Log output stream |
| `cluster` | `dev`, `integration`, `live` | Cluster name |

## LogQL Syntax Cheat Sheet

| Operator | Description | Example |
|----------|-------------|---------|
| `\|=` | Contains | `{app="x"} \|= "error"` |
| `!=` | Not contains | `{app="x"} != "debug"` |
| `\|~` | Regex match | `{app="x"} \|~ "err\|warn"` |
| `!~` | Not regex match | `{app="x"} !~ "health"` |
| `\| json` | Parse JSON | `{app="x"} \| json` |
| `\| logfmt` | Parse logfmt | `{app="x"} \| logfmt` |
| `\| regexp` | Regex extract | `{app="x"} \| regexp "..."` |
| `\| line_format` | Reformat line | `{app="x"} \| line_format "{{.msg}}"` |
| `\| unwrap` | Extract numeric | `... \| unwrap duration` |
| `rate()` | Lines per second | `rate({app="x"}[5m])` |
| `count_over_time()` | Line count | `count_over_time({app="x"}[5m])` |
| `bytes_rate()` | Bytes per second | `bytes_rate({app="x"}[5m])` |
| `sum by()` | Aggregate | `sum by(ns) (rate(...))` |
| `topk()` | Top N | `topk(5, sum by(pod) (...))` |
