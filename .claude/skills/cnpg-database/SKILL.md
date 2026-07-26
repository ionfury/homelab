---
name: cnpg-database
description: |
  CloudNative-PG (CNPG) PostgreSQL database management for the Kubernetes homelab.
  Covers shared platform cluster, dedicated per-app clusters, credential provisioning,
  cross-namespace replication via kubernetes-replicator, and monitoring.

  Use when: (1) Adding a new database for an application, (2) Creating a dedicated CNPG cluster,
  (3) Setting up database credentials and cross-namespace replication, (4) Debugging database
  connectivity or CNPG cluster health, (5) Adding PostgreSQL extensions for specialized workloads.

  Triggers: "database", "postgresql", "postgres", "cnpg", "cloudnative-pg", "pooler",
  "pgbouncer", "database credentials", "db password", "managed roles", "Database CRD",
  "database cluster", "shared database", "dedicated database", "cnpg cluster"
user-invocable: false
---

# CNPG Database Management

## Architecture Overview

All clusters live in the `database` namespace. The **shared platform cluster** (`platform-0/1/2`) uses `spec.managed.roles` + Database CRDs per app, with PgBouncer pooler at `platform-pooler-rw.database.svc`. **Dedicated clusters** (e.g., Immich) bootstrap their own DB and owner via `initdb`. In both cases, credentials are replicated via kubernetes-replicator to the consumer app namespace.

## Decision Tree: Shared vs Dedicated Cluster

Standard workload, no special extensions → shared cluster (`platform-pooler-rw.database.svc`)
Needs custom extensions (vector, PostGIS) or isolation → dedicated cluster with custom `imageName`
Unclear → start with shared, migrate if needed

---

## Key Files (Shared Cluster)

Location: `kubernetes/platform/config/database/`

| File | Purpose |
|------|---------|
| `cluster.yaml` | CNPG Cluster CR with `spec.managed.roles` |
| `databases.yaml` | Database CRDs (one per app database) |
| `role-secrets.yaml` | Per-role password secrets (secret-generator + replicator) |
| `pooler.yaml` | PgBouncer Pooler (`platform-pooler-rw`) |
| `superuser-secret.yaml` | Auto-generated superuser password (database ns only) |
| `prometheus-rules.yaml` | CNPG-specific PrometheusRules |

For manifest examples, see [references/cluster-reference.md](references/cluster-reference.md).

---

## Workflow: Add a Database for a New App (Shared Cluster)

Steps 1-3 edit files in `kubernetes/platform/config/database/`. Steps 4-5 are in the app's cluster config.

**Step 1: Add managed role** to `cluster.yaml` `spec.managed.roles`. Template: see [references/cluster-reference.md](references/cluster-reference.md#managed-role-fields).

**Step 2: Create role password secret** in `role-secrets.yaml`. Template: see [references/credentials.md](references/credentials.md#role-password-secret-template).

**Step 3: Create Database CRD** in `databases.yaml`. Template: see [references/cluster-reference.md](references/cluster-reference.md#database-crd-fields).

Note: Apps with multiple databases (sonarr-main, sonarr-log) share one role; create separate Database CRs with the same `owner`.

**Step 4: Create credential replica** in `kubernetes/clusters/<cluster>/config/<app>/`. Template: see [references/credentials.md](references/credentials.md#app-namespace-replica-template).

**Step 5: Add network policy access label** `access.network-policy.homelab/postgres: "true"` to the namespace entry in `kubernetes/platform/namespaces.yaml`.

**Step 6: Register** the credential replica in the app's `kustomization.yaml`.

For credential chain diagrams, see [references/credentials.md](references/credentials.md).

---

## Workflow: Create a Dedicated CNPG Cluster

Use when the app needs custom PostgreSQL extensions or performance/data isolation.

**Step 1: Define the Cluster** at `kubernetes/clusters/<cluster>/config/<app>/<app>-cluster.yaml`. Set `inheritedMetadata` to allow replication of the auto-generated app secret. For a full manifest example, see [references/cluster-reference.md](references/cluster-reference.md).

Key differences vs shared cluster:

| Feature | Shared | Dedicated |
|---------|--------|-----------|
| Location | `kubernetes/platform/config/database/` | `kubernetes/clusters/<cluster>/config/<app>/` |
| Image | Standard PostgreSQL | Custom image with extensions |
| Role management | `spec.managed.roles` + Database CRDs | `bootstrap.initdb` creates DB and owner |
| Credential source | `<app>-role-password` (secret-generator) | `<app>-database-app` (CNPG auto-generated) |
| `inheritedMetadata` | Not needed | Required for secret replication |

**Step 2: Replicate app credentials** to the consumer namespace. CNPG auto-generates `<cluster-name>-app` in `database`. The `inheritedMetadata` annotations enable replication. Template: see [references/credentials.md](references/credentials.md#app-namespace-replica-template).

Real example: `kubernetes/clusters/live/config/immich/database-secret-replication.yaml`

**Step 3:** Add the `access.network-policy.homelab/postgres: "true"` label to the app namespace and register all files in `kustomization.yaml`.

---

## Monitoring

Both Cluster and Pooler set `monitoring.enablePodMonitor: true` — Prometheus discovers them automatically. No manual ServiceMonitor needed.

CNPG alerts are in `kubernetes/platform/config/database/prometheus-rules.yaml`:

| Alert | Condition | Severity |
|-------|-----------|----------|
| `CNPGClusterNotHealthy` | `cnpg_pg_replication_streaming == 0` | critical |
| `CNPGClusterHighConnections` | Connection usage > 80% of `max_connections` | warning |
| `CNPGInstanceNotReady` | Replica WAL receiver down | critical |

Key metrics: `cnpg_pg_replication_streaming`, `cnpg_pg_stat_activity_count`, `cnpg_pg_settings_setting{name="max_connections"}`, `cnpg_pg_replication_is_wal_receiver_up`.

---

## Debugging

Use `scripts/check-connection.sh <cluster> <app-namespace> [app-name]` for structured health checks.

Common issues:

| Symptom | Cause | Fix |
|---------|-------|-----|
| Pods Pending | No PVs available | Check StorageClass `fast` exists, Longhorn healthy |
| CrashLoopBackOff | OOM or bad config | Check `kubectl logs`, increase memory limits |
| App can't connect | Network policy missing | Add `access.network-policy.homelab/postgres: "true"` |
| App can't connect | Secret not replicated | Check replication annotations on source secret |
| Secret empty after replication | Source namespace wrong | Verify `replicate-from` points to correct `<ns>/<name>` |
| Extension not found | Wrong image | Verify `imageName` includes the extension |
| Database not created | Database CRD missing | Add Database CR to `databases.yaml` |
| Role not created | Missing from managed.roles | Add role entry to `cluster.yaml` |
| Role password mismatch | Secret not regenerated | Delete the role-password secret; secret-generator recreates it |

Manual connectivity test: `kubectl run -n <app-ns> pg-test --rm -it --image=postgres:17 -- psql "postgresql://user:pass@platform-pooler-rw.database.svc:5432/dbname"`

---

## Cross-References

| Document | Relevance |
|----------|-----------|
| [references/cluster-reference.md](references/cluster-reference.md) | Cluster CRD fields and full manifest examples |
| [references/credentials.md](references/credentials.md) | Credential chain diagrams and secret templates |
| [scripts/check-connection.sh](scripts/check-connection.sh) | Structured health check commands |
| [secrets skill](../secrets/SKILL.md) | secret-generator, ExternalSecret, and replication patterns |
| [deploy-app skill](../deploy-app/SKILL.md) | End-to-end deployment including database setup |
| [kubernetes/platform/config/CLAUDE.md](../../../kubernetes/platform/config/CLAUDE.md) | Config subsystem and CRD dependency patterns |
