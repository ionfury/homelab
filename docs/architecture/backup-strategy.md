# Architecture: Storage and Backup Strategy

This document describes the current storage classification and data protection strategy across the homelab Kubernetes platform. It is a living document -- update it as the system evolves.

---

## Storage Class Taxonomy

Every persistent volume in the cluster uses one of four storage classes. Each class encodes replication, disk tier, and backup behavior at the StorageClass level, so workloads inherit the correct data protection simply by choosing the right class.

| Storage Class | Replicas (dev/int/live) | Disk Tier | Longhorn Snapshots | Longhorn Backups (S3) | FS Trim | Use Case |
|---|---|---|---|---|---|---|
| `fast` | 1/3/3 | fast (NVMe) | Every 4h, retain 12 | Every 6h (per-cluster) | Daily | Critical user data (games, app state) |
| `slow` | 1/3/3 | slow (HDD) | Every 4h, retain 12 | Every 6h (per-cluster) | Daily | Bulk user data (photo library) |
| `fast-nb` | 1/3/3 | fast (NVMe) | Every 4h, retain 12 | None | Daily | Data not requiring off-site backup (observability, app-replicated) |
| `slow-nb` | 1/3/3 | slow (HDD) | Every 4h, retain 12 | None | Daily | Bulk data not requiring off-site backup |

> **Note:** `nb` = "no backup". Backup recurring jobs (`backup-frequent`) are defined per-cluster, not at the platform level. The `fast` and `slow` storage classes reference the `backup-frequent` group, which must exist in each cluster's config to enable S3 backups. Currently defined for live and dev clusters.

### How It Works

Storage classes are defined in `kubernetes/platform/config/longhorn/storage-classes/`. Each class specifies:

- **`numberOfReplicas`**: `${storage_replica_count}` (computed from machine count, capped at 3) for all classes
- **`diskSelector`**: Routes volumes to the correct disk tier (`fast` for NVMe, `slow` for HDD)
- **`recurringJobSelectors`**: JSON array of recurring job groups that attach snapshot, backup, and trim schedules

Platform-level recurring jobs are defined in `kubernetes/platform/config/longhorn/recurring-jobs/`:

| Job | Schedule | Task | Retain | Concurrency |
|-----|----------|------|--------|-------------|
| `snapshot-daily` | `0 1 * * *` (01:00 UTC) | snapshot | 3 | 5 |
| `snapshot-frequent` | `0 */4 * * *` (every 4h) | snapshot | 12 | 5 |
| `snapshot-minimal` | `0 1 * * *` (01:00 UTC) | snapshot | 1 | 5 |
| `filesystem-trim-daily` | `0 4 * * *` (04:00 UTC) | filesystem-trim | N/A | 1 |

Backup recurring jobs are defined per-cluster in `kubernetes/clusters/<cluster>/config/longhorn-backup-jobs/`:

| Job | Schedule | Task | Retain | Clusters |
|-----|----------|------|--------|----------|
| `backup-frequent` | `0 */6 * * *` (every 6h) | backup | 28 (live) / 7 (dev) | live, dev |
| `backup-daily` | `0 2 * * *` (02:00 UTC) | backup | 7 | live only |

### Why Four Classes?

The classes represent distinct data protection tiers rather than a one-size-fits-all approach:

- **`fast` / `slow`**: Full protection for data that cannot be recreated. The only difference is disk tier (NVMe vs HDD) for cost-performance tradeoffs on large volumes. These reference the `backup-frequent` group for S3 backups.
- **`fast-nb` / `slow-nb`**: Same replica count and snapshot schedule as their backed-up counterparts, but without S3 backups. Used for data that either has its own backup mechanism (CNPG Barman, Dragonfly S3 snapshots), is re-derivable (Prometheus, Loki), or is internally replicated at the application layer (Garage).

---

## Complete Data Protection Matrix

Every workload with persistent state, its storage class, protection mechanisms, and recovery characteristics for the live cluster.

| Workload | Storage Class | Volume Size (live) | Longhorn S3 Backup | App-Level Backup | Backup Target | RPO | Retention |
|---|---|---|---|---|---|---|---|
| Immich Library | `slow` | 500Gi | Yes | No | AWS S3 | 6h | 7 days |
| Prometheus | `fast-nb` | 50Gi | No | No | Local only | N/A (re-derivable) | N/A |
| Loki | `fast-nb` | 50Gi | No | No | Local only | N/A (re-derivable) | N/A |
| Satisfactory | `fast` | 30Gi | Yes | No | AWS S3 | 6h | 7 days |
| Valheim | `fast` | 10Gi | Yes | Yes (built-in) | AWS S3 + local saves | 6h | 7d + 10 saves |
| Factorio | `fast` | 10Gi | Yes | No | AWS S3 | 6h | 7 days |
| Garage Metadata | `fast-nb` | 10Gi | No | No | Local only (app-replicated) | N/A | N/A |
| Garage Data | `fast-nb` | 100Gi | No | No | Local only (app-replicated) | N/A | N/A |
| Platform PostgreSQL | `fast-nb` | 20Gi | No | Barman to Garage S3 | Garage S3 (internal) | Continuous WAL | 14 days |
| Immich PostgreSQL | `fast-nb` | 10Gi | No | Barman to Garage S3 | Garage S3 (internal) | Continuous WAL | 14 days |
| Dragonfly snapshot buffer | `fast-nb` | 2Gi | No | S3 snapshots to Garage | Garage S3 (internal) | 6h | Rolling |
| Immich ML Cache | `fast-nb` | 10Gi | No | None | N/A | N/A (rebuildable) | N/A |
| Grafana | Stateless | -- | -- | -- | -- | -- | -- |
| Kromgo | Stateless | -- | -- | -- | -- | -- | -- |

### Reading the Matrix

- **Longhorn S3 Backup**: Whether Longhorn's `backup-frequent` recurring job sends volume snapshots to AWS S3. Controlled by the StorageClass recurring job selectors and per-cluster backup job definitions.
- **App-Level Backup**: Whether the application itself has a backup mechanism independent of Longhorn (e.g., Barman WAL streaming, Dragonfly S3 snapshots, Valheim's built-in save system).
- **RPO (Recovery Point Objective)**: Maximum data loss in a disaster. "24h" means up to one day of data could be lost (daily backup schedule). "Continuous WAL" means near-zero data loss.
- **Retention**: How long backups are kept before expiration.

---

## Backup Targets

Data flows to two distinct S3 endpoints, each serving a different purpose.

### AWS S3 (External, Off-Site)

**Purpose:** Longhorn volume backups for disaster recovery.

- **What goes here:** Longhorn backup-frequent snapshots from `fast` and `slow` storage classes
- **How:** Longhorn connects to AWS S3 via IAM credentials provisioned by the `storage` infrastructure stack and injected via ExternalSecret (`kubernetes/platform/config/longhorn/backup/external-secret.yaml`)
- **Bucket naming:** `homelab-longhorn-backup-{dev,integration,live}` (one per cluster)
- **Durability:** AWS S3 standard (11 nines)
- **Why external:** Off-site backup is the last line of defense. If the entire cluster (including Garage) is lost, Longhorn backups in AWS S3 enable full volume restoration

### Garage S3 (Internal, Same-Cluster)

**Purpose:** Application-level backups that need S3-compatible storage.

- **What goes here:** CNPG WAL archives + base backups, Dragonfly snapshots
- **How:** Applications connect to Garage via its in-cluster S3 API (`${garage_s3_endpoint}`)
- **Buckets:** `cnpg-platform-backups`, `cnpg-immich-backups`, `dragonfly-snapshots`
- **Durability:** Garage's own replication factor (`${default_replica_count}`) on `fast-nb` volumes with local snapshots

---

## Backup Data Flow

### Longhorn Path (Volume-Level)

```
Application Volume
      |
      v
Longhorn Snapshot (local, scheduled by recurring job)
      |
      v
Longhorn Backup (incremental, uploaded by recurring job)
      |
      v
AWS S3 Bucket (homelab-longhorn-backup-<cluster>)
```

This path protects `fast` and `slow` volumes (which reference the `backup-frequent` group). The `fast-nb` and `slow-nb` classes opt out of this path entirely (no backup group in their recurring job selectors).

### CNPG Path (Database-Level)

```
PostgreSQL (primary)
      |
      |-- Continuous WAL streaming --> Barman --> Garage S3 bucket
      |                                            |
      '-- Periodic base backup -----> Barman --> Garage S3 bucket
                                                   |
                                                   v
                                      Garage volumes (fast-nb PVCs)
                                                   |
                                                   v
                                      Local snapshots (every 4h)
```

CNPG databases use `fast-nb` storage (no direct Longhorn S3 backup) because Barman provides continuous WAL archiving with lower RPO. The Barman archives live in Garage S3, and Garage's own PVCs have local snapshots for point-in-time recovery.

### Dragonfly Path (Cache-Level)

```
Dragonfly (in-memory cache)
      |
      v
S3 snapshot (every 6h, cron: "0 */6 * * *")
      |
      v
Garage S3 bucket (dragonfly-snapshots/)
      |
      v
Garage volumes (fast-nb PVCs)
      |
      v
Local snapshots (every 4h)
```

Dragonfly uses `fast-nb` for its snapshot buffer PVC and writes snapshots directly to Garage S3. Like the CNPG path, Garage's PVCs have local snapshots for point-in-time recovery.

---

## Conscious Tradeoffs

These are deliberate architectural decisions, not oversights. Each represents a cost-benefit analysis.

### 1. CNPG Backups Route Through Internal Garage, Not Directly to AWS S3

**Decision:** PostgreSQL WAL archives go to Garage S3 (internal) rather than directly to AWS S3.

**Why:** This keeps the backup configuration uniform -- everything ultimately reaches AWS S3 through Longhorn. CNPG's Barman supports S3-compatible endpoints but not all the IAM authentication patterns used for Longhorn. Using Garage as an intermediary simplifies credential management and lets Longhorn handle the external upload.

**Trade-off:** Creates a layered dependency -- if Garage is down, new WAL archives cannot be written. Acceptable because Garage runs with `${default_replica_count}` replicas and PostgreSQL retains unarchived WAL segments locally until Garage recovers.

### 2. Garage PVCs Use `fast-nb` Without S3 Backup

**Decision:** Garage PVCs use `fast-nb` (no S3 backup), relying on Garage's internal replication and local Longhorn snapshots.

**Why:** Garage replicates data at the application layer across nodes. Adding Longhorn S3 backups on top of that would create redundant off-site copies of data that is already replicated. The `fast-nb` class provides local snapshots (every 4h, retain 12) for point-in-time recovery without the S3 cost.

**Trade-off:** No off-site backup for Garage data. If the entire cluster is lost, Garage data (including CNPG barman archives and Dragonfly snapshots stored within it) would be lost. This is acceptable because Garage data is re-derivable -- CNPG can rebuild from WAL replay, and Dragonfly is a cache.

### 3. Prometheus and Loki Are Not Backed Up to S3

**Decision:** Observability data uses `fast-nb` with no S3 backup.

**Why:** Metrics and logs are re-derivable data. Prometheus re-scrapes all targets on startup and rebuilds its TSDB. Loki ingests new log streams continuously. Losing historical data is inconvenient but not catastrophic -- it does not affect application functionality or user data.

**Trade-off:** After a disaster recovery, dashboards will show gaps in historical data. Acceptable because the alternative (backing up 50Gi+ of observability data to S3) is expensive relative to the value of that data.

### 4. Database Volumes Use `fast-nb` Despite Being Critical

**Decision:** CNPG clusters use StorageClass `fast-nb` (no S3 backup) despite PostgreSQL data being critical.

**Why:** Databases have their own backup mechanism (Barman) that provides better RPO (continuous WAL) than Longhorn's 6-hourly schedule ever could. Using `fast-nb` avoids paying for redundant Longhorn-level S3 backups on data that is already protected by a superior mechanism. The `fast-nb` class still provides local snapshots (every 4h) as an additional safety net.

**Trade-off:** Database volumes have no direct off-site backup via Longhorn. Off-site durability depends on the CNPG→Barman→Garage chain. Mitigated by this documentation and the explicit `backup:` configuration in every CNPG Cluster manifest.

### 5. Snapshot and Backup Frequency Varies by Storage Class

**Decision:** High-value user data gets more frequent snapshots and backups; observability data gets minimal protection.

**Why:** Not all data has equal recovery value. Game saves and user photos justify higher backup frequency because loss is permanent. Observability data regenerates naturally. Tiered frequency reduces storage costs and backup job contention.

**Trade-off:** More complex StorageClass definitions with different recurring job group assignments. Accepted because the complexity is encoded in the StorageClass (single point of configuration) and workloads remain unaware of the backup tier.


---

## Per-Cluster Differences

Cluster environments differ in replica count and volume sizing. All clusters use the same storage class definitions and recurring job schedules -- only the substitution variables change.

| Dimension | dev | integration | live |
|-----------|-----|-------------|------|
| Machine count | 1 | 3 | 3 |
| `storage_replica_count` | 1 | 3 | 3 |
| `default_replica_count` | 1 | 3 | 3 |
| `storage_provisioning` | minimal | minimal | normal |
| Prometheus volume | 10Gi | 10Gi | 50Gi |
| Loki volume | 10Gi | 10Gi | 50Gi |
| Garage data volume | 10Gi | 10Gi | 100Gi |
| Garage metadata volume | 2Gi | 2Gi | 10Gi |
| Database volume | 5Gi | 5Gi | 20Gi |
| Dragonfly volume | 1Gi | 1Gi | 2Gi |

These values are derived from `infrastructure/modules/config/main.tf`:

- **`storage_replica_count`** and **`default_replica_count`**: `min(3, machine_count)` -- ensures single-node dev clusters do not request 3 replicas
- **Volume sizes**: Lookup table indexed by `storage_provisioning` variable (`normal` for live, `minimal` for dev/integration)
- **Stack configuration**: Each stack declares its `storage_provisioning` in `infrastructure/stacks/<cluster>/terragrunt.stack.hcl`

---

## DR Validation

A disaster recovery exercise plan exists at `docs/plans/longhorn-dr-exercise.md`. The plan defines an automated workflow to:

1. Deploy a test workload with known data to the dev cluster
2. Back up the volume to AWS S3 via Longhorn
3. Destroy and rebuild the dev cluster from scratch
4. Restore the volume from S3
5. Verify data integrity

**Status:** Planned but not yet exercised. The exercise will validate the complete backup chain from volume snapshot through S3 restoration.

---

## Key File References

| File | Purpose |
|------|---------|
| `kubernetes/platform/config/longhorn/storage-classes/` | StorageClass definitions (fast, slow, fast-nb, slow-nb) |
| `kubernetes/platform/config/longhorn/recurring-jobs/` | Platform snapshot and trim schedules |
| `kubernetes/clusters/*/config/longhorn-backup-jobs/` | Per-cluster backup recurring jobs |
| `kubernetes/platform/config/longhorn/backup/` | Longhorn S3 backup target credentials |
| `kubernetes/platform/config/database/cluster.yaml` | Platform CNPG cluster with Barman backup config |
| `kubernetes/clusters/live/config/immich/immich-cluster.yaml` | Immich-dedicated CNPG cluster with Barman backup |
| `kubernetes/platform/config/dragonfly/dragonfly-instance.yaml` | Dragonfly S3 snapshot configuration |
| `kubernetes/platform/config/garage/garage-cluster.yaml` | Garage replication and storage settings |
| `infrastructure/modules/config/main.tf` | Per-cluster volume sizes and replica counts |
| `infrastructure/stacks/*/terragrunt.stack.hcl` | Per-cluster `storage_provisioning` setting |
| `docs/plans/longhorn-dr-exercise.md` | DR exercise plan |
| `docs/runbooks/longhorn-disaster-recovery.md` | DR execution runbook |
