# CNPG Credential Chain Reference

## Shared Cluster Credential Flow

```
database namespace                          app namespace
┌──────────────────────┐                    ┌──────────────────────┐
│ <app>-role-password   │  kubernetes-       │ <app>-db-credentials │
│ (secret-generator)    │──replicator──────► │ (replica)            │
│  username: <app>      │                    │  username: <app>     │
│  password: <random>   │                    │  password: <random>  │
└──────────────────────┘                    └──────────────────────┘
         │
         ▼
  CNPG Cluster (managed role)
  uses passwordSecret to set PostgreSQL role password
         │
         ▼
  Database CRD
  creates DB owned by role
```

**Key security property:** The superuser secret (`cnpg-platform-superuser`) never leaves
the `database` namespace. App namespaces only receive their own role password.

## Dedicated Cluster Credential Flow

```
CNPG auto-generates              kubernetes-replicator
     │                                   │
     ▼                                   ▼
<app>-database-app  ──────────► cnpg-<app>-database-app
  (database ns)                   (app ns)
```

The `inheritedMetadata` annotations on the dedicated cluster CR make the auto-generated
app secret replicable to target namespaces.

## Secret Types by Cluster Type

| Feature | Shared Cluster | Dedicated Cluster |
|---------|---------------|-------------------|
| Credential source | `<app>-role-password` (secret-generator) | `<app>-database-app` (CNPG auto-generated) |
| `inheritedMetadata` | Not needed (role secrets have explicit replication) | Required for app secret replication |
| Superuser | Confined to `database` namespace | CNPG auto-generates (`<cluster-name>-superuser`) |

## Role Password Secret Template

```yaml
# kubernetes/platform/config/database/role-secrets.yaml
apiVersion: v1
kind: Secret
metadata:
  name: <app>-role-password
  namespace: database
  annotations:
    secret-generator.v1.mittwald.de/autogenerate: password
    secret-generator.v1.mittwald.de/encoding: hex
    secret-generator.v1.mittwald.de/length: "32"
    replicator.v1.mittwald.de/replication-allowed: "true"
    replicator.v1.mittwald.de/replication-allowed-namespaces: "<app-namespace>"
type: kubernetes.io/basic-auth
stringData:
  username: <app>
```

## App-Namespace Replica Template

```yaml
# kubernetes/clusters/<cluster>/config/<app>/<app>-db-credentials.yaml
apiVersion: v1
kind: Secret
metadata:
  name: <app>-db-credentials
  namespace: <app-namespace>
  annotations:
    replicator.v1.mittwald.de/replicate-from: database/<app>-role-password
type: kubernetes.io/basic-auth
data: { }
```

For dedicated clusters, the replica references the CNPG-generated app secret:

```yaml
# kubernetes/clusters/<cluster>/config/<app>/database-secret-replication.yaml
apiVersion: v1
kind: Secret
metadata:
  name: cnpg-<app>-database-app
  namespace: <app-namespace>
  annotations:
    replicator.v1.mittwald.de/replicate-from: database/<app>-database-app
data: { }
```

Real examples:
- `kubernetes/clusters/live/config/authelia-prereqs/authelia-db-credentials.yaml`
- `kubernetes/clusters/live/config/immich/database-secret-replication.yaml`

## App Connection Settings (Shared Cluster via Pooler)

| Setting | Value |
|---------|-------|
| Host | `platform-pooler-rw.database.svc` |
| Port | `5432` |
| Database | `<app>` (created by CNPG Database CRD) |
| Username | From `<app>-db-credentials` secret (`username` key) |
| Password | From `<app>-db-credentials` secret (`password` key) |
