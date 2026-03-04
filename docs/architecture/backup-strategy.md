# Architecture: Storage and Backup Strategy

This document describes the current storage classification and data protection strategy across the homelab Kubernetes platform. It is a living document -- update it as the system evolves.

---

## Storage Class Taxonomy

Every persistent volume in the cluster uses one of two storage classes. Each class encodes replication, disk tier, and snapshot behavior at the StorageClass level.

| Storage Class | Replicas (dev/int/live) | Disk Tier | Longhorn Snapshots | FS Trim | Use Case |
|---|---|---|---|---|---|
| `fast` | 1/3/3 | fast (NVMe) | Every 4h, retain 12 | Daily | All NVMe-backed workloads |
| `slow` | 1/3/3 | slow (HDD) | Every 4h, retain 12 | Daily | Bulk data on HDD |

> **Note:** Backup orchestration is handled by Velero at the orchestration layer, not by Longhorn recurring jobs. The previous `fast-nb` / `slow-nb` "no-backup" variants have been removed -- the distinction is no longer needed with Velero managing backup selection.

### How It Works

Storage classes are defined in `kubernetes/platform/config/longhorn/storage-classes/`. Each class specifies:

- **`numberOfReplicas`**: `${storage_replica_count}` (computed from machine count, capped at 3) for all classes
- **`diskSelector`**: Routes volumes to the correct disk tier (`fast` for NVMe, `slow` for HDD)
- **`recurringJobSelectors`**: JSON array of recurring job groups that attach snapshot and trim schedules

Platform-level recurring jobs are defined in `kubernetes/platform/config/longhorn/recurring-jobs/`:

| Job | Schedule | Task | Retain | Concurrency |
|-----|----------|------|--------|-------------|
| `snapshot-daily` | `0 1 * * *` (01:00 UTC) | snapshot | 3 | 5 |
| `snapshot-frequent` | `0 */4 * * *` (every 4h) | snapshot | 12 | 5 |
| `snapshot-minimal` | `0 1 * * *` (01:00 UTC) | snapshot | 1 | 5 |
| `filesystem-trim-daily` | `0 4 * * *` (04:00 UTC) | filesystem-trim | N/A | 1 |

### Why Two Classes?

The two classes represent the two physical disk tiers in the cluster:

- **`fast`**: NVMe-backed storage for performance-sensitive workloads (databases, caches, application state)
- **`slow`**: HDD-backed storage for bulk data where capacity matters more than IOPS (media libraries)

Both classes share identical snapshot and trim schedules. Backup decisions are made at the Velero level, not the StorageClass level, allowing backup policies to be managed independently of storage provisioning.

---

## Complete Data Protection Matrix

Every workload with persistent state, its storage class, protection mechanisms, and recovery characteristics for the live cluster.

| Workload | Storage Class | Volume Size (live) | Velero Backup | App-Level Backup | Backup Target | RPO | Retention |
|---|---|---|---|---|---|---|---|
| Immich Library | `slow` | 500Gi | Yes | No | AWS S3 | 6h | 7 days |
| Prometheus | `fast` | 50Gi | No | No | Local only | N/A (re-derivable) | N/A |
| Loki | `fast` | 50Gi | No | No | Local only | N/A (re-derivable) | N/A |
| Satisfactory | `fast` | 30Gi | Yes | No | AWS S3 | 6h | 7 days |
| Valheim | `fast` | 10Gi | Yes | Yes (built-in) | AWS S3 + local saves | 6h | 7d + 10 saves |
| Factorio | `fast` | 10Gi | Yes | No | AWS S3 | 6h | 7 days |
| Garage Metadata | `fast` | 10Gi | No | No | Local only (app-replicated) | N/A | N/A |
| Garage Data | `fast` | 100Gi | No | No | Local only (app-replicated) | N/A | N/A |
| Platform PostgreSQL | `fast` | 20Gi | No | Barman to Garage S3 | Garage S3 (internal) | Continuous WAL | 14 days |
| Immich PostgreSQL | `fast` | 10Gi | No | Barman to Garage S3 | Garage S3 (internal) | Continuous WAL | 14 days |
| Dragonfly snapshot buffer | `fast` | 2Gi | No | S3 snapshots to Garage | Garage S3 (internal) | 6h | Rolling |
| Immich ML Cache | `fast` | 10Gi | No | None | N/A | N/A (rebuildable) | N/A |
| Grafana | Stateless | -- | -- | -- | -- | -- | -- |
| Kromgo | Stateless | -- | -- | -- | -- | -- | -- |

### Reading the Matrix

- **Velero Backup**: Whether Velero includes this volume in scheduled backup jobs. Controlled by Velero backup schedules and label selectors, not by StorageClass.
- **App-Level Backup**: Whether the application itself has a backup mechanism independent of Longhorn (e.g., Barman WAL streaming, Dragonfly S3 snapshots, Valheim's built-in save system).
- **RPO (Recovery Point Objective)**: Maximum data loss in a disaster. "24h" means up to one day of data could be lost (daily backup schedule). "Continuous WAL" means near-zero data loss.
- **Retention**: How long backups are kept before expiration.

---

## Backup Targets

Data flows to two distinct S3 endpoints, each serving a different purpose.

### AWS S3 (External, Off-Site)

**Purpose:** Longhorn volume backups for disaster recovery.

- **What goes here:** Velero volume snapshots for selected workloads
- **How:** Velero connects to AWS S3 via IAM credentials for scheduled and on-demand backups
- **Bucket naming:** `homelab-longhorn-backup-{dev,integration,live}` (one per cluster)
- **Durability:** AWS S3 standard (11 nines)
- **Why external:** Off-site backup is the last line of defense. If the entire cluster (including Garage) is lost, Velero backups in AWS S3 enable full volume restoration

### Garage S3 (Internal, Same-Cluster)

**Purpose:** Application-level backups that need S3-compatible storage.

- **What goes here:** CNPG WAL archives + base backups, Dragonfly snapshots
- **How:** Applications connect to Garage via its in-cluster S3 API (`${garage_s3_endpoint}`)
- **Buckets:** `cnpg-platform-backups`, `cnpg-immich-backups`, `dragonfly-snapshots`
- **Durability:** Garage's own replication factor (`${default_replica_count}`) on `fast` volumes with local snapshots

---

## Backup Data Flow

### Velero Path (Volume-Level)

```
Application Volume
      |
      v
Longhorn Snapshot (local, scheduled by recurring job)
      |
      v
Velero Backup (orchestration-layer, scheduled or on-demand)
      |
      v
AWS S3 Bucket (homelab-longhorn-backup-<cluster>)
```

Velero selects which workloads to back up via label selectors and schedule definitions, decoupling backup policy from storage provisioning.

### CNPG Path (Database-Level)

```
PostgreSQL (primary)
      |
      |-- Continuous WAL streaming --> Barman --> Garage S3 bucket
      |                                            |
      '-- Periodic base backup -----> Barman --> Garage S3 bucket
                                                   |
                                                   v
                                      Garage volumes (fast PVCs)
                                                   |
                                                   v
                                      Local snapshots (every 4h)
```

CNPG databases use `fast` storage with Barman providing continuous WAL archiving for low RPO. The Barman archives live in Garage S3, and Garage's own PVCs have local snapshots for point-in-time recovery. Velero excludes these volumes from scheduled backups since Barman provides superior protection.

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
Garage volumes (fast PVCs)
      |
      v
Local snapshots (every 4h)
```

Dragonfly uses `fast` for its snapshot buffer PVC and writes snapshots directly to Garage S3. Like the CNPG path, Garage's PVCs have local snapshots for point-in-time recovery.

---

## Conscious Tradeoffs

These are deliberate architectural decisions, not oversights. Each represents a cost-benefit analysis.

### 1. CNPG Backups Route Through Internal Garage, Not Directly to AWS S3

**Decision:** PostgreSQL WAL archives go to Garage S3 (internal) rather than directly to AWS S3.

**Why:** This keeps the backup configuration uniform -- everything ultimately reaches AWS S3 through Longhorn. CNPG's Barman supports S3-compatible endpoints but not all the IAM authentication patterns used for Longhorn. Using Garage as an intermediary simplifies credential management and lets Longhorn handle the external upload.

**Trade-off:** Creates a layered dependency -- if Garage is down, new WAL archives cannot be written. Acceptable because Garage runs with `${default_replica_count}` replicas and PostgreSQL retains unarchived WAL segments locally until Garage recovers.

### 2. Garage PVCs Are Not Backed Up by Velero

**Decision:** Garage PVCs use `fast` storage but are excluded from Velero backup schedules, relying on Garage's internal replication and local Longhorn snapshots.

**Why:** Garage replicates data at the application layer across nodes. Adding Velero backups on top of that would create redundant off-site copies of data that is already replicated. Local snapshots (every 4h, retain 12) provide point-in-time recovery without the S3 cost.

**Trade-off:** No off-site backup for Garage data. If the entire cluster is lost, Garage data (including CNPG barman archives and Dragonfly snapshots stored within it) would be lost. This is acceptable because Garage data is re-derivable -- CNPG can rebuild from WAL replay, and Dragonfly is a cache.

### 3. Prometheus and Loki Are Not Backed Up by Velero

**Decision:** Observability data uses `fast` storage but is excluded from Velero backup schedules.

**Why:** Metrics and logs are re-derivable data. Prometheus re-scrapes all targets on startup and rebuilds its TSDB. Loki ingests new log streams continuously. Losing historical data is inconvenient but not catastrophic -- it does not affect application functionality or user data.

**Trade-off:** After a disaster recovery, dashboards will show gaps in historical data. Acceptable because the alternative (backing up 50Gi+ of observability data to S3) is expensive relative to the value of that data.

### 4. Database Volumes Are Not Backed Up by Velero

**Decision:** CNPG clusters use `fast` storage but are excluded from Velero backup schedules despite PostgreSQL data being critical.

**Why:** Databases have their own backup mechanism (Barman) that provides better RPO (continuous WAL) than Velero's scheduled backups ever could. Excluding them from Velero avoids paying for redundant backups on data that is already protected by a superior mechanism. Local snapshots (every 4h) provide an additional safety net.

**Trade-off:** Database volumes have no direct off-site backup via Velero. Off-site durability depends on the CNPG->Barman->Garage chain. Mitigated by this documentation and the explicit `backup:` configuration in every CNPG Cluster manifest.

### 5. Backup Selection Is Managed at the Velero Layer

**Decision:** Backup decisions are made by Velero via label selectors and schedule definitions, not encoded in StorageClass recurring job groups.

**Why:** Decoupling backup policy from storage provisioning simplifies the storage class taxonomy (two classes instead of four) and gives Velero full control over what gets backed up, when, and where. This is a cleaner separation of concerns -- StorageClasses handle provisioning (disk tier, replication, snapshots), while Velero handles backup orchestration.

**Trade-off:** Backup behavior is no longer implicit from the StorageClass name. Operators must check Velero schedules to understand which workloads are backed up. Accepted because Velero provides richer backup policies (label selectors, inclusion/exclusion rules) than StorageClass recurring job groups ever could.


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
| `kubernetes/platform/config/longhorn/storage-classes/` | StorageClass definitions (fast, slow) |
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
