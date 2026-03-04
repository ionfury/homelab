# Database Alerts

Operational procedures for CNPG (CloudNative-PG PostgreSQL) and Dragonfly (Redis-compatible cache) alerts.

## Overview

The homelab runs two database tiers:

- **CNPG PostgreSQL**: Shared platform cluster (3 instances, max_connections=200) and dedicated Immich cluster (3 instances, max_connections=100). PgBouncer poolers front both clusters (1000 max_client_conn, 25 default_pool_size per database, transaction mode). Daily ScheduledBackups at 03:00 UTC with WAL archiving to Garage S3.
- **Dragonfly**: Redis-compatible cache in the `cache` namespace (3 replicas, 768 MB maxmemory, cache_mode enabled). Snapshots every 6 hours to Garage S3.

## Quick Reference

| Alert | Severity | For | Signal |
|-------|----------|-----|--------|
| [CNPGClusterNotHealthy](#cnpgclusternothealthy) | critical | 5m | No streaming replicas on primary |
| [CNPGInstanceNotReady](#cnpginstancenotready) | critical | 5m | Replica WAL receiver disconnected |
| [CNPGClusterHighConnections](#cnpgclusterhighconnections) | warning | 5m | Backend connections >80% of max_connections |
| [CNPGWALArchivingLagHigh](#cnpgwalarchivinglaghigh) | warning | 5m | >10 WAL files pending archival |
| [CNPGWALArchivingStalled](#cnpgwalarchivingstalled) | critical | 5m | >100 WAL files pending archival |
| [CNPGBackupStale](#cnpgbackupstale) | critical | 10m | No backup within 48 hours |
| [CNPGBackupFailed](#cnpgbackupfailed) | warning | 5m | Latest backup attempt failed |
| [DragonflyDown](#dragonflydown) | critical | 2m | Instance unreachable by Prometheus |
| [DragonflyHighMemoryUsage](#dragonflyhighmemoryusage) | warning | 5m | Memory >90% of maxmemory |
| [DragonflyHighMemoryUsageCritical](#dragonflyhighmemoryusagecritical) | critical | 2m | Memory >95% of maxmemory |
| [DragonflySnapshotsFailing](#dragonflysnapshotsfailing) | warning | 10m | Snapshot backup failures in last hour |

## Triage Tree

```mermaid
flowchart TD
    A{"Which service\nis alerting?"} -->|"CNPG"| B{"Alert category?"}
    A -->|"Dragonfly"| C{"Alert category?"}

    B -->|"Cluster health"| D["CNPGClusterNotHealthy\nCNPGInstanceNotReady"]
    B -->|"Connections"| E["CNPGClusterHighConnections"]
    B -->|"Backup / WAL"| F["CNPGWALArchivingLagHigh\nCNPGWALArchivingStalled\nCNPGBackupStale\nCNPGBackupFailed"]

    C -->|"Instance health"| G["DragonflyDown"]
    C -->|"Resources"| H["DragonflyHighMemoryUsage\nDragonflyHighMemoryUsageCritical"]
    C -->|"Snapshots"| I["DragonflySnapshotsFailing"]

    D --> D1{"Primary or\nreplica issue?"}
    D1 -->|"Primary has\n0 replicas"| D2["Check replica pod status\nCheck replication slots\nCheck WAL sender processes"]
    D1 -->|"Replica WAL\nreceiver down"| D3["Check replica logs\nCheck network to primary\nCheck pg_stat_replication"]

    E --> E1["Check active connections\nIdentify top consumers\nReview pooler metrics"]

    F --> F1{"WAL or\nbackup?""}
    F1 -->|"WAL archiving"| F2["Check Garage S3 health\nCheck barman logs\nVerify S3 credentials"]
    F1 -->|"Backup"| F3["Check ScheduledBackup status\nCheck CNPG operator logs\nVerify barman connectivity"]

    G --> G1["Check pod status\nCheck node health\nCheck resource limits"]

    H --> H1["Check key count growth\nCheck eviction rate\nReview connected clients"]

    I --> I1["Check Garage S3 health\nCheck Dragonfly logs\nVerify S3 credentials"]
```

## CNPG Cluster Health

### CNPGClusterNotHealthy

**Severity**: critical | **For**: 5m

The primary instance reports zero streaming replicas. All replicas have disconnected from replication. Data redundancy is lost and failover capability is unavailable.

**Expression**: `cnpg_pg_replication_streaming_replicas == 0 and cnpg_pg_replication_in_recovery == 0`

**Diagnosis**:

```bash
# Check cluster status
KUBECONFIG=~/.kube/live.yaml kubectl get cluster -n database

# Check all pods
KUBECONFIG=~/.kube/live.yaml kubectl get pods -n database -l cnpg.io/cluster

# Check replication status from primary
KUBECONFIG=~/.kube/live.yaml kubectl exec -n database <primary-pod> -c postgres -- \
  psql -U postgres -c "SELECT * FROM pg_stat_replication;"

# Check CNPG operator logs for failover or fencing events
KUBECONFIG=~/.kube/live.yaml kubectl logs -n cnpg-system -l app.kubernetes.io/name=cloudnative-pg --tail=100

# Query current metric value
KUBECONFIG=~/.kube/live.yaml kubectl exec -n monitoring prometheus-kube-prometheus-stack-0 -c prometheus -- \
  wget -qO- 'http://localhost:9090/api/v1/query?query=cnpg_pg_replication_streaming_replicas' | jq '.data.result'
```

**Resolution**:

1. If replica pods are not running, check events and logs for crash reasons
2. If replica pods are running but not streaming, check replication slots and WAL sender processes
3. If the primary was fenced by the operator, check CNPG operator logs for the fencing reason
4. Verify network connectivity between primary and replicas (Cilium/Hubble)

### CNPGInstanceNotReady

**Severity**: critical | **For**: 5m

A replica is in recovery mode but its WAL receiver is not connected. The replica cannot follow the primary and will fall behind.

**Expression**: `cnpg_pg_replication_in_recovery == 1 and cnpg_pg_replication_is_wal_receiver_up == 0`

**Diagnosis**:

```bash
# Check WAL receiver status on the replica
KUBECONFIG=~/.kube/live.yaml kubectl exec -n database <replica-pod> -c postgres -- \
  psql -U postgres -c "SELECT * FROM pg_stat_wal_receiver;"

# Check replica logs for connection errors
KUBECONFIG=~/.kube/live.yaml kubectl logs -n database <replica-pod> -c postgres --tail=100

# Check replication lag
KUBECONFIG=~/.kube/live.yaml kubectl exec -n monitoring prometheus-kube-prometheus-stack-0 -c prometheus -- \
  wget -qO- 'http://localhost:9090/api/v1/query?query=cnpg_pg_replication_lag' | jq '.data.result'
```

**Resolution**:

1. Check if the primary is healthy and accepting replication connections
2. Verify replication slots are not blocked (`pg_replication_slots` on primary)
3. Check for WAL segment gaps that prevent the replica from catching up
4. If the replica is too far behind, it may need to be re-cloned from a base backup

## CNPG Connections

### CNPGClusterHighConnections

**Severity**: warning | **For**: 5m

Backend connections are approaching max_connections. The pooler (PgBouncer) has 1000 max_client_conn with 25 default_pool_size per database. Server-side connections are bounded by max_connections (200 platform, 100 dedicated).

**Expression**: `(sum by (pod) (cnpg_backends_total) / on(pod) cnpg_pg_settings_setting{name="max_connections"}) > 0.8`

**Diagnosis**:

```bash
# Check current connection count vs max
KUBECONFIG=~/.kube/live.yaml kubectl exec -n monitoring prometheus-kube-prometheus-stack-0 -c prometheus -- \
  wget -qO- 'http://localhost:9090/api/v1/query?query=sum%20by%20(pod)%20(cnpg_backends_total)' | jq '.data.result'

# Break down connections by database and state
KUBECONFIG=~/.kube/live.yaml kubectl exec -n database <pod> -c postgres -- \
  psql -U postgres -c "SELECT datname, state, count(*) FROM pg_stat_activity GROUP BY datname, state ORDER BY count DESC;"

# Check pooler connections
KUBECONFIG=~/.kube/live.yaml kubectl exec -n database <pooler-pod> -- \
  psql -U pgbouncer -h 127.0.0.1 -p 5432 pgbouncer -c "SHOW POOLS;"
```

**Resolution**:

1. Identify which databases/clients consume the most connections
2. Check for connection leaks (long-idle connections in `pg_stat_activity`)
3. Review pooler configuration: `default_pool_size=25` may need adjustment
4. If a specific application is the source, fix connection management in the application
5. As a last resort, increase `max_connections` in the CNPG Cluster spec (requires pod restart)

**Thresholds**: The 80% threshold at max_connections=200 fires at 160 connections. Normal steady-state is approximately 26 connections on the platform cluster.

## CNPG Backup and WAL

### CNPGWALArchivingLagHigh

**Severity**: warning | **For**: 5m

More than 10 WAL files are pending archival. WAL archive lag degrades recovery point objective (RPO).

**Expression**: `cnpg_collector_pg_wal_archive_status{value="ready"} > 10`

**Diagnosis**:

```bash
# Check current WAL archive status
KUBECONFIG=~/.kube/live.yaml kubectl exec -n monitoring prometheus-kube-prometheus-stack-0 -c prometheus -- \
  wget -qO- 'http://localhost:9090/api/v1/query?query=cnpg_collector_pg_wal_archive_status' | jq '.data.result'

# Check barman-cloud logs in the postgres container
KUBECONFIG=~/.kube/live.yaml kubectl logs -n database <primary-pod> -c postgres --tail=50 | grep -i "archive\|barman\|wal"

# Verify Garage S3 connectivity
KUBECONFIG=~/.kube/live.yaml kubectl exec -n database <primary-pod> -c postgres -- \
  barman-cloud-check-wal-archive --cloud-provider aws-s3 --endpoint-url http://garage.garage-system.svc:3900 s3://cnpg-platform-backups/ platform
```

**Resolution**:

1. Check Garage health: `kubectl get pods -n garage-system`
2. Verify S3 credentials are valid (ExternalSecret sync)
3. Check for network policy issues between database and garage-system namespaces
4. If Garage is healthy, check for pg_wal disk pressure on the Longhorn volume

### CNPGWALArchivingStalled

**Severity**: critical | **For**: 5m

More than 100 WAL files are pending archival. Archiving appears stalled. RPO is severely degraded and pg_wal disk usage will grow until the volume fills.

**Expression**: `cnpg_collector_pg_wal_archive_status{value="ready"} > 100`

**Diagnosis**: Same as CNPGWALArchivingLagHigh, with additional urgency.

```bash
# Check pg_wal directory size
KUBECONFIG=~/.kube/live.yaml kubectl exec -n database <primary-pod> -c postgres -- \
  du -sh /var/lib/postgresql/data/pgdata/pg_wal/

# Check volume usage
KUBECONFIG=~/.kube/live.yaml kubectl exec -n monitoring prometheus-kube-prometheus-stack-0 -c prometheus -- \
  wget -qO- 'http://localhost:9090/api/v1/query?query=kubelet_volume_stats_used_bytes%7Bnamespace%3D%22database%22%7D%20/%20kubelet_volume_stats_capacity_bytes%7Bnamespace%3D%22database%22%7D' | jq '.data.result'
```

**Resolution**:

1. Follow CNPGWALArchivingLagHigh diagnosis first
2. If Garage S3 is down, prioritize restoring Garage
3. Monitor pg_wal volume usage -- if it fills, PostgreSQL will halt
4. If volume is near capacity, consider expanding the Longhorn volume (see `docs/runbooks/resize-volume.md`)

**Threshold justification**: Each WAL file is 16 MB. 100 files is 1.6 GB of unarchived WAL. At default WAL generation rates, this represents significant S3 downtime.

### CNPGBackupStale

**Severity**: critical | **For**: 10m

No successful backup exists within 48 hours. The daily ScheduledBackup runs at 03:00 UTC, so 48 hours means two consecutive missed backups.

**Expression**: `(time() - cnpg_collector_last_available_backup_timestamp) > 172800 and cnpg_collector_last_available_backup_timestamp > 0`

**Diagnosis**:

```bash
# Check ScheduledBackup resource status
KUBECONFIG=~/.kube/live.yaml kubectl get scheduledbackups -n database
KUBECONFIG=~/.kube/live.yaml kubectl describe scheduledbackup -n database <name>

# Check recent backup objects
KUBECONFIG=~/.kube/live.yaml kubectl get backups -n database --sort-by='.metadata.creationTimestamp'

# Check backup age metric
KUBECONFIG=~/.kube/live.yaml kubectl exec -n monitoring prometheus-kube-prometheus-stack-0 -c prometheus -- \
  wget -qO- 'http://localhost:9090/api/v1/query?query=time()%20-%20cnpg_collector_last_available_backup_timestamp' | jq '.data.result'

# Check CNPG operator logs for backup errors
KUBECONFIG=~/.kube/live.yaml kubectl logs -n cnpg-system -l app.kubernetes.io/name=cloudnative-pg --tail=100 | grep -i backup
```

**Resolution**:

1. Check if ScheduledBackup is suspended or misconfigured
2. Check if the CNPG operator is healthy and running
3. Verify Garage S3 connectivity (common root cause for both WAL and backup failures)
4. Manually trigger a backup if needed: create a Backup CR referencing the cluster

### CNPGBackupFailed

**Severity**: warning | **For**: 5m

The most recent backup attempt failed. A single failure may be transient; the next scheduled backup at 03:00 UTC may succeed.

**Expression**: `cnpg_collector_last_failed_backup_timestamp > cnpg_collector_last_available_backup_timestamp`

**Diagnosis**:

```bash
# Check the failed backup resource
KUBECONFIG=~/.kube/live.yaml kubectl get backups -n database --sort-by='.metadata.creationTimestamp' | tail -5

# Describe the most recent backup for error details
KUBECONFIG=~/.kube/live.yaml kubectl describe backup -n database <latest-backup>

# Check CNPG operator logs
KUBECONFIG=~/.kube/live.yaml kubectl logs -n cnpg-system -l app.kubernetes.io/name=cloudnative-pg --tail=100 | grep -i "backup\|error"
```

**Resolution**:

1. If this is a single failure, wait for the next scheduled backup
2. If failures are recurring, investigate Garage S3 connectivity
3. Check for volume snapshot issues if using Longhorn-based backups
4. Verify barman-cloud credentials and endpoint configuration

## Dragonfly Health

### DragonflyDown

**Severity**: critical | **For**: 2m

A Dragonfly instance is unreachable by Prometheus. Applications using Dragonfly as a cache will fall back to database queries, increasing database load.

**Expression**: `up{job="cache/dragonfly"} == 0`

**Diagnosis**:

```bash
# Check Dragonfly pods
KUBECONFIG=~/.kube/live.yaml kubectl get pods -n cache

# Check pod events
KUBECONFIG=~/.kube/live.yaml kubectl describe pod -n cache <pod>

# Check Dragonfly logs
KUBECONFIG=~/.kube/live.yaml kubectl logs -n cache <pod> --tail=100

# Check node health where the pod runs
KUBECONFIG=~/.kube/live.yaml kubectl get nodes -o wide
```

**Resolution**:

1. If the pod is not running, check events for scheduling failures or resource constraints
2. If the pod is running but Prometheus cannot scrape, check the PodMonitor and network policies
3. If the node is unhealthy, the pod will be rescheduled automatically
4. Dragonfly runs in `cache_mode` with replication -- a single instance loss does not cause data loss

### Note on scrape target labels

The Dragonfly PodMonitor creates targets with `job="cache/dragonfly"` (namespace/name format). The Dragonfly operator does not set an `app` label that matches the `up` metric, so matching must use the `job` label.

## Dragonfly Resources

### DragonflyHighMemoryUsage

**Severity**: warning | **For**: 5m

Dragonfly memory usage exceeds 90% of the configured maxmemory (768 MB). In cache_mode, Dragonfly evicts keys when the limit is reached, but sustained high usage may indicate insufficient capacity.

**Expression**: `(dragonfly_memory_used_bytes{namespace="cache"} / dragonfly_memory_max_bytes{namespace="cache"}) > 0.9`

**Diagnosis**:

```bash
# Check current memory usage
KUBECONFIG=~/.kube/live.yaml kubectl exec -n monitoring prometheus-kube-prometheus-stack-0 -c prometheus -- \
  wget -qO- 'http://localhost:9090/api/v1/query?query=dragonfly_memory_used_bytes%7Bnamespace%3D%22cache%22%7D' | jq '.data.result'

# Check key count
KUBECONFIG=~/.kube/live.yaml kubectl exec -n monitoring prometheus-kube-prometheus-stack-0 -c prometheus -- \
  wget -qO- 'http://localhost:9090/api/v1/query?query=dragonfly_db_keys%7Bnamespace%3D%22cache%22%7D' | jq '.data.result'

# Check connected clients
KUBECONFIG=~/.kube/live.yaml kubectl exec -n cache <dragonfly-pod> -- redis-cli INFO clients
```

**Resolution**:

1. Check which databases (by index) consume the most keys
2. Identify if a specific application is storing more data than expected
3. In `cache_mode`, eviction is automatic -- this alert indicates capacity pressure, not imminent failure
4. Consider increasing `maxmemory` in the Dragonfly CR if eviction rates are causing performance issues

### DragonflyHighMemoryUsageCritical

**Severity**: critical | **For**: 2m

Memory usage exceeds 95% of maxmemory. Heavy eviction is likely in progress. The short `for` duration (2 minutes) reflects that eviction storms can degrade performance quickly.

**Expression**: `(dragonfly_memory_used_bytes{namespace="cache"} / dragonfly_memory_max_bytes{namespace="cache"}) > 0.95`

**Resolution**:

1. Follow DragonflyHighMemoryUsage diagnosis
2. Check eviction rate: `redis-cli INFO stats | grep evicted_keys`
3. If eviction rate is high, applications may experience elevated cache miss rates
4. Consider increasing `maxmemory` in the Dragonfly CR (`dragonfly-instance.yaml`)

## Dragonfly Snapshots

### DragonflySnapshotsFailing

**Severity**: warning | **For**: 10m

Dragonfly snapshot backups are failing. The operator schedules snapshots every 6 hours to Garage S3. In `cache_mode`, data loss on pod restart without snapshots means cold cache startup.

**Expression**: `rate(dragonfly_failed_backups_total[1h]) > 0`

**Diagnosis**:

```bash
# Check Dragonfly logs for backup errors
KUBECONFIG=~/.kube/live.yaml kubectl logs -n cache <dragonfly-pod> --tail=100 | grep -i "backup\|snapshot\|s3\|error"

# Check Garage S3 health
KUBECONFIG=~/.kube/live.yaml kubectl get pods -n garage-system

# Verify S3 credentials secret
KUBECONFIG=~/.kube/live.yaml kubectl get secret -n cache dragonfly-s3-credentials

# Check failed backup counter
KUBECONFIG=~/.kube/live.yaml kubectl exec -n monitoring prometheus-kube-prometheus-stack-0 -c prometheus -- \
  wget -qO- 'http://localhost:9090/api/v1/query?query=dragonfly_failed_backups_total' | jq '.data.result'
```

**Resolution**:

1. Check Garage S3 health and connectivity
2. Verify S3 credentials have not expired or been rotated
3. Check network policies between `cache` and `garage-system` namespaces
4. Check Dragonfly logs for specific S3 error messages (auth, bucket not found, etc.)
5. Since Dragonfly runs in `cache_mode`, snapshot loss means cold cache on restart but no permanent data loss

## Verification

After resolving any alert, verify it clears:

```bash
# Check currently firing alerts
KUBECONFIG=~/.kube/live.yaml kubectl exec -n monitoring prometheus-kube-prometheus-stack-0 -c prometheus -- \
  wget -qO- 'http://localhost:9090/api/v1/alerts' | jq '.data.alerts[] | select(.state == "firing") | select(.labels.alertname | startswith("CNPG") or startswith("Dragonfly"))'
```

## Related

- [Longhorn Disaster Recovery](longhorn-disaster-recovery.md) -- includes database volume recovery
- [Resize Volume](resize-volume.md) -- for expanding database volumes when pg_wal fills
- CNPG cluster config: `kubernetes/platform/config/database/cluster.yaml`
- Dragonfly instance config: `kubernetes/platform/config/dragonfly/dragonfly-instance.yaml`
- CNPG alert rules: `kubernetes/platform/config/database/prometheus-rules.yaml`
- Dragonfly alert rules: `kubernetes/platform/config/dragonfly/prometheus-rules.yaml`
