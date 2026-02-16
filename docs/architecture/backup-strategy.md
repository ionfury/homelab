# Architecture: Storage and Backup Strategy

This document describes the current storage classification and data protection strategy across the homelab Kubernetes platform. It is a living document -- update it as the system evolves.

---

## Storage Class Taxonomy

Every persistent volume in the cluster uses one of five storage classes. Each class encodes replication, disk tier, and backup behavior at the StorageClass level, so workloads inherit the correct data protection simply by choosing the right class.

| Storage Class | Replicas (dev/int/live) | Disk Tier | Longhorn Snapshots | Longhorn Backups (S3) | FS Trim | Use Case |
|---|---|---|---|---|---|---|
| `fast` | 1/3/3 | fast (NVMe) | Daily, retain 3 | Daily, retain 7 | Daily | Critical user data (games, app state) |
| `slow` | 1/3/3 | slow (HDD) | Daily, retain 3 | Daily, retain 7 | Daily | Bulk user data (photo library) |
| `fast-nr` | 1/1/1 | fast (NVMe) | Daily, retain 3 | Daily, retain 7 | Daily | Internally-replicated apps (Garage) |
| `fast-local` | 1/3/3 | fast (NVMe) | Daily, retain 1 | None | Daily | Re-derivable observability data |
| `ephemeral` | 1/1/1 | fast (NVMe) | None | None | None | Temporary/app-managed-backup data |

> **Note:** `fast-local` and tiered backup frequency (more frequent snapshots for high-value data) are being implemented in a parallel PR. The table above reflects the target state. Until that PR merges, `fast` and `slow` use the same `snapshot-daily` / `backup-daily` / `filesystem-trim-daily` recurring job groups as `fast-nr`.

### How It Works

Storage classes are defined in `kubernetes/platform/config/longhorn/storage-classes/`. Each class specifies:

- **`numberOfReplicas`**: Either `${storage_replica_count}` (computed from machine count, capped at 3) or hardcoded `"1"` for `fast-nr` and `ephemeral`
- **`diskSelector`**: Routes volumes to the correct disk tier (`fast` for NVMe, `slow` for HDD)
- **`recurringJobSelectors`**: JSON array of recurring job groups that attach snapshot, backup, and trim schedules

Recurring jobs are defined in `kubernetes/platform/config/longhorn/recurring-jobs/`:

| Job | Schedule | Task | Retain | Concurrency |
|-----|----------|------|--------|-------------|
| `snapshot-daily` | `0 1 * * *` (01:00 UTC) | snapshot | 3 | 5 |
| `backup-daily` | `0 2 * * *` (02:00 UTC) | backup | 7 | 2 |
| `filesystem-trim-daily` | `0 4 * * *` (04:00 UTC) | filesystem-trim | N/A | 1 |

### Why Five Classes?

The classes represent distinct data protection tiers rather than a one-size-fits-all approach:

- **`fast` / `slow`**: Full protection for data that cannot be recreated. The only difference is disk tier (NVMe vs HDD) for cost-performance tradeoffs on large volumes.
- **`fast-nr`**: Single Longhorn replica because the application already replicates internally (Garage uses `replication.factor: ${default_replica_count}`). Still backed up to S3 because internal replication does not protect against cluster-wide loss.
- **`fast-local`**: Full replica count for availability but no S3 backup. Observability data (Prometheus, Loki) is re-derivable from live metrics and can be rebuilt by simply re-scraping.
- **`ephemeral`**: No Longhorn-level protection at all. Used exclusively by workloads with their own backup mechanism (CNPG Barman, Dragonfly S3 snapshots) or truly disposable data.

---

## Complete Data Protection Matrix

Every workload with persistent state, its storage class, protection mechanisms, and recovery characteristics for the live cluster.

| Workload | Storage Class | Volume Size (live) | Longhorn S3 Backup | App-Level Backup | Backup Target | RPO | Retention |
|---|---|---|---|---|---|---|---|
| Immich Library | `slow` | 500Gi | Yes | No | AWS S3 | 24h | 7 days |
| Prometheus | `fast-local` (target) | 50Gi | No | No | Local only | N/A (re-derivable) | N/A |
| Loki | `fast-local` (target) | 50Gi | No | No | Local only | N/A (re-derivable) | N/A |
| Satisfactory | `fast` | 30Gi | Yes | No | AWS S3 | 24h | 7 days |
| Valheim | `fast` | 10Gi | Yes | Yes (built-in) | AWS S3 + local saves | 24h | 7d + 10 saves |
| Factorio | `fast` | 10Gi | Yes | No | AWS S3 | 24h | 7 days |
| Garage Metadata | `fast-nr` | 10Gi | Yes (x3 PVCs) | No | AWS S3 | 24h | 7 days |
| Garage Data | `fast-nr` | 100Gi | Yes (x3 PVCs) | No | AWS S3 | 24h | 7 days |
| Platform PostgreSQL | `ephemeral` | 20Gi | No | Barman to Garage S3 | Garage S3 (internal) | Continuous WAL | 14 days |
| Immich PostgreSQL | `ephemeral` | 10Gi | No | Barman to Garage S3 | Garage S3 (internal) | Continuous WAL | 14 days |
| Dragonfly snapshot buffer | `ephemeral` | 2Gi | No | S3 snapshots to Garage | Garage S3 (internal) | 6h | Rolling |
| Immich ML Cache | `ephemeral` | 10Gi | No | None | N/A | N/A (rebuildable) | N/A |
| Grafana | Stateless | -- | -- | -- | -- | -- | -- |
| Kromgo | Stateless | -- | -- | -- | -- | -- | -- |

> **Note:** Prometheus and Loki currently use `fast` storage class. The migration to `fast-local` is part of the tiered backup PR.

### Reading the Matrix

- **Longhorn S3 Backup**: Whether Longhorn's `backup-daily` recurring job sends volume snapshots to AWS S3. Controlled by the StorageClass recurring job selectors.
- **App-Level Backup**: Whether the application itself has a backup mechanism independent of Longhorn (e.g., Barman WAL streaming, Dragonfly S3 snapshots, Valheim's built-in save system).
- **RPO (Recovery Point Objective)**: Maximum data loss in a disaster. "24h" means up to one day of data could be lost (daily backup schedule). "Continuous WAL" means near-zero data loss.
- **Retention**: How long backups are kept before expiration.

---

## Backup Targets

Data flows to two distinct S3 endpoints, each serving a different purpose.

### AWS S3 (External, Off-Site)

**Purpose:** Longhorn volume backups for disaster recovery.

- **What goes here:** Longhorn backup-daily snapshots from `fast`, `slow`, and `fast-nr` storage classes
- **How:** Longhorn connects to AWS S3 via IAM credentials provisioned by the `storage` infrastructure stack and injected via ExternalSecret (`kubernetes/platform/config/longhorn/backup/external-secret.yaml`)
- **Bucket naming:** `homelab-longhorn-backup-{dev,integration,live}` (one per cluster)
- **Durability:** AWS S3 standard (11 nines)
- **Why external:** Off-site backup is the last line of defense. If the entire cluster (including Garage) is lost, Longhorn backups in AWS S3 enable full volume restoration

### Garage S3 (Internal, Same-Cluster)

**Purpose:** Application-level backups that need S3-compatible storage.

- **What goes here:** CNPG WAL archives + base backups, Dragonfly snapshots
- **How:** Applications connect to Garage via its in-cluster S3 API (`${garage_s3_endpoint}`)
- **Buckets:** `cnpg-platform-backups`, `cnpg-immich-backups`, `dragonfly-snapshots`
- **Durability:** Garage's own replication factor (`${default_replica_count}`) on `fast-nr` volumes, which are themselves backed up to AWS S3

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

This path protects `fast`, `slow`, and `fast-nr` volumes. The `ephemeral` and `fast-local` classes opt out of this path entirely (no `backup-daily` group in their recurring job selectors).

### CNPG Path (Database-Level)

```
PostgreSQL (primary)
      |
      |-- Continuous WAL streaming --> Barman --> Garage S3 bucket
      |                                            |
      '-- Periodic base backup -----> Barman --> Garage S3 bucket
                                                   |
                                                   v
                                      Garage volumes (fast-nr PVCs)
                                                   |
                                                   v
                                      Longhorn backup-daily
                                                   |
                                                   v
                                      AWS S3 (off-site)
```

CNPG databases use `ephemeral` storage (no direct Longhorn backup) because Barman provides continuous WAL archiving with lower RPO. The Barman archives live in Garage S3, and Garage's own PVCs are backed up to AWS S3 via Longhorn -- creating a layered backup chain.

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
Garage volumes (fast-nr PVCs)
      |
      v
Longhorn backup-daily
      |
      v
AWS S3 (off-site)
```

Dragonfly uses `ephemeral` for its snapshot buffer PVC and writes snapshots directly to Garage S3. Like the CNPG path, ultimate off-site durability comes through Garage's Longhorn backups.

---

## Conscious Tradeoffs

These are deliberate architectural decisions, not oversights. Each represents a cost-benefit analysis.

### 1. CNPG Backups Route Through Internal Garage, Not Directly to AWS S3

**Decision:** PostgreSQL WAL archives go to Garage S3 (internal) rather than directly to AWS S3.

**Why:** This keeps the backup configuration uniform -- everything ultimately reaches AWS S3 through Longhorn. CNPG's Barman supports S3-compatible endpoints but not all the IAM authentication patterns used for Longhorn. Using Garage as an intermediary simplifies credential management and lets Longhorn handle the external upload.

**Trade-off:** Creates a layered dependency -- if Garage is down, new WAL archives cannot be written. Acceptable because Garage runs with `${default_replica_count}` replicas and PostgreSQL retains unarchived WAL segments locally until Garage recovers.

### 2. Garage's Three PVCs Are All Backed Up to AWS S3

**Decision:** All three Garage PVCs (metadata + data per replica) are included in Longhorn's daily backup to AWS S3.

**Why:** Longhorn recurring jobs operate at the StorageClass level. The `fast-nr` class includes the `backup-daily` group, so every `fast-nr` volume is backed up. There is no per-volume opt-out mechanism in Longhorn's recurring job model.

**Trade-off:** This triples the backup cost for Garage data that is already internally replicated. Accepted because the storage cost is modest and the alternative (a separate storage class just for Garage without backups) adds complexity without meaningful benefit.

### 3. Prometheus and Loki Are Not Backed Up to S3

**Decision:** Observability data uses `fast-local` (target state) with no S3 backup.

**Why:** Metrics and logs are re-derivable data. Prometheus re-scrapes all targets on startup and rebuilds its TSDB. Loki ingests new log streams continuously. Losing historical data is inconvenient but not catastrophic -- it does not affect application functionality or user data.

**Trade-off:** After a disaster recovery, dashboards will show gaps in historical data. Acceptable because the alternative (backing up 50Gi+ of observability data to S3) is expensive relative to the value of that data.

### 4. `ephemeral` Naming Is Retained for Database Volumes

**Decision:** CNPG clusters use StorageClass `ephemeral` despite PostgreSQL data being critical.

**Why:** The name describes Longhorn's treatment of the volume (single replica, no snapshots, no backups), not the importance of the data. Databases have their own backup mechanism (Barman) that provides better RPO (continuous WAL) than Longhorn's daily schedule ever could. Using `ephemeral` avoids paying for redundant Longhorn-level backups on data that is already protected by a superior mechanism.

**Trade-off:** The name `ephemeral` can be misleading for database volumes. Mitigated by this documentation and the explicit `backup:` configuration in every CNPG Cluster manifest.

### 5. Snapshot and Backup Frequency Varies by Storage Class

**Decision:** High-value user data gets more frequent snapshots and backups; observability data gets minimal protection.

**Why:** Not all data has equal recovery value. Game saves and user photos justify higher backup frequency because loss is permanent. Observability data regenerates naturally. Tiered frequency reduces storage costs and backup job contention.

**Trade-off:** More complex StorageClass definitions with different recurring job group assignments. Accepted because the complexity is encoded in the StorageClass (single point of configuration) and workloads remain unaware of the backup tier.

> **Note:** Tiered frequency is being implemented in a parallel PR. Currently all backed-up classes use the same daily schedule.

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
| `kubernetes/platform/config/longhorn/storage-classes/` | StorageClass definitions (fast, slow, fast-nr, ephemeral) |
| `kubernetes/platform/config/longhorn/recurring-jobs/` | Snapshot, backup, and trim schedules |
| `kubernetes/platform/config/longhorn/backup/` | Longhorn S3 backup target credentials |
| `kubernetes/platform/config/database/cluster.yaml` | Platform CNPG cluster with Barman backup config |
| `kubernetes/clusters/live/config/immich/immich-cluster.yaml` | Immich-dedicated CNPG cluster with Barman backup |
| `kubernetes/platform/config/dragonfly/dragonfly-instance.yaml` | Dragonfly S3 snapshot configuration |
| `kubernetes/platform/config/garage/garage-cluster.yaml` | Garage replication and storage settings |
| `infrastructure/modules/config/main.tf` | Per-cluster volume sizes and replica counts |
| `infrastructure/stacks/*/terragrunt.stack.hcl` | Per-cluster `storage_provisioning` setting |
| `docs/plans/longhorn-dr-exercise.md` | DR exercise plan |
| `docs/runbooks/longhorn-disaster-recovery.md` | DR execution runbook |
