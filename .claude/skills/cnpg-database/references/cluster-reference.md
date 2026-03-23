# CNPG Cluster CRD Field Reference

## Cluster Spec Fields

| Field | Purpose | Example |
|-------|---------|---------|
| `instances` | Number of PostgreSQL instances (primary + replicas) | `${default_replica_count}` |
| `imageName` | PostgreSQL container image | `ghcr.io/cloudnative-pg/postgresql:17.2` |
| `primaryUpdateStrategy` | How to handle primary upgrades | `unsupervised` (automatic failover) |
| `enableSuperuserAccess` | Whether to allow superuser connections | `true` for shared, not set for dedicated |
| `superuserSecret` | Reference to superuser credentials | `cnpg-platform-superuser` |
| `managed.roles` | Declarative PostgreSQL role definitions | See Managed Roles section |
| `storage.storageClass` | Kubernetes StorageClass for PVCs | `fast` |
| `storage.size` | Volume size per instance | `${database_volume_size}` or `10Gi` |
| `monitoring.enablePodMonitor` | Auto-create PodMonitor for Prometheus | `true` |
| `affinity.enablePodAntiAffinity` | Spread instances across nodes | `true` |
| `postgresql.pg_hba` | Client authentication rules | Allow pod CIDR with SCRAM-SHA-256 |
| `inheritedMetadata` | Annotations/labels applied to generated secrets | Replication annotations |

## Managed Role Fields

| Field | Purpose | Example |
|-------|---------|---------|
| `name` | PostgreSQL role name | `authelia` |
| `ensure` | Whether role should exist | `present` |
| `login` | Whether role can log in | `true` |
| `passwordSecret.name` | Secret containing the role password | `authelia-role-password` |

## Database CRD Fields

| Field | Purpose | Example |
|-------|---------|---------|
| `spec.name` | PostgreSQL database name | `authelia` |
| `spec.owner` | Database owner (must be a managed role) | `authelia` |
| `spec.cluster.name` | Target CNPG Cluster | `platform` |
| `spec.databaseReclaimPolicy` | What happens when CRD is deleted | `retain` (keeps database) |

## Pooler Spec Fields

| Field | Purpose | Example |
|-------|---------|---------|
| `cluster.name` | Target CNPG Cluster | `platform` |
| `instances` | Number of PgBouncer pods | `${default_replica_count}` |
| `type` | Access mode (`rw` or `ro`) | `rw` |
| `pgbouncer.poolMode` | Connection pooling mode | `transaction` |
| `pgbouncer.parameters.max_client_conn` | Max client connections | `"1000"` |
| `pgbouncer.parameters.default_pool_size` | Default server connections per pool | `"25"` |

## Bootstrap initdb Fields (Dedicated Clusters Only)

| Field | Purpose | Example |
|-------|---------|---------|
| `database` | Database name to create | `immich` |
| `owner` | Database owner role | `immich` |
| `postInitApplicationSQL` | SQL to run after database creation | `CREATE EXTENSION IF NOT EXISTS ...` |

## Shared Cluster Example (kubernetes/platform/config/database/cluster.yaml)

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: platform
spec:
  description: "Shared platform PostgreSQL cluster"
  imageName: ghcr.io/cloudnative-pg/postgresql:17.2
  instances: ${default_replica_count}
  primaryUpdateStrategy: unsupervised
  enableSuperuserAccess: true
  superuserSecret:
    name: cnpg-platform-superuser
  managed:
    roles:
      - name: authelia
        ensure: present
        login: true
        passwordSecret:
          name: authelia-role-password
  postgresql:
    parameters:
      shared_buffers: "256MB"
      max_connections: "200"
      effective_cache_size: "512MB"
      log_statement: "ddl"
      log_min_duration_statement: "1000"
    pg_hba:
      - host all all 10.0.0.0/8 scram-sha-256
      - host all all 172.16.0.0/12 scram-sha-256
  storage:
    storageClass: fast
    size: ${database_volume_size}
  monitoring:
    enablePodMonitor: true
  affinity:
    enablePodAntiAffinity: true
    topologyKey: kubernetes.io/hostname
```

## PgBouncer Pooler Example (kubernetes/platform/config/database/pooler.yaml)

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Pooler
metadata:
  name: platform-pooler-rw
spec:
  cluster:
    name: platform
  instances: ${default_replica_count}
  type: rw
  pgbouncer:
    poolMode: transaction
    parameters:
      max_client_conn: "1000"
      default_pool_size: "25"
  monitoring:
    enablePodMonitor: true
```

## Dedicated Cluster Example (with extensions)

```yaml
# yaml-language-server: $schema=https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/postgresql.cnpg.io/cluster_v1.json
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: <app>-database
  namespace: database
spec:
  inheritedMetadata:
    annotations:
      replicator.v1.mittwald.de/replication-allowed: "true"
      replicator.v1.mittwald.de/replication-allowed-namespaces: "<app-namespace>"
  description: "<App> PostgreSQL with <extension> support"
  imageName: <custom-image>  # e.g., ghcr.io/tensorchord/cloudnative-vectorchord:17.7-1.0.0
  instances: ${default_replica_count}
  primaryUpdateStrategy: unsupervised
  postgresql:
    shared_preload_libraries:
      - "<extension>.so"
    parameters:
      shared_buffers: "128MB"
      max_connections: "100"
  bootstrap:
    initdb:
      database: <app>
      owner: <app>
      postInitApplicationSQL:
        - CREATE EXTENSION IF NOT EXISTS <extension> CASCADE;
  storage:
    storageClass: fast
    size: 10Gi
  resources:
    requests:
      cpu: 50m
      memory: 256Mi
    limits:
      memory: 1Gi
  monitoring:
    enablePodMonitor: true
  affinity:
    enablePodAntiAffinity: true
    topologyKey: kubernetes.io/hostname
```

Real example: `kubernetes/clusters/live/config/immich/immich-cluster.yaml`
