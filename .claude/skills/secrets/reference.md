# Secrets Reference

## Mechanism Comparison

| Mechanism | Persistence | Generation | Use Case |
|-----------|-------------|------------|----------|
| secret-generator | Ephemeral (lost on rebuild) | In-cluster random | Session secrets, DB passwords |
| ExternalSecret | Persistent (data in AWS SSM) | Manual / external | OAuth tokens, API keys, cloud creds |
| app-secrets module | Persistent (stored in SSM) | Terragrunt random | Encryption keys that survive rebuilds |
| kubernetes-replicator | Mirrors source | N/A | Sharing secrets across namespaces |

## secret-generator Annotation Reference

| Annotation | Required | Values | Default |
|------------|----------|--------|---------|
| `secret-generator.v1.mittwald.de/autogenerate` | Yes | Comma-separated key names | — |
| `secret-generator.v1.mittwald.de/encoding` | No | `hex`, `base64`, `base32`, `raw` | `base64` |
| `secret-generator.v1.mittwald.de/length` | No | Integer string (e.g., `"32"`) | `"40"` |

## ExternalSecret Failure Causes

| Symptom | Cause | Fix |
|---------|-------|-----|
| `SecretSyncedError` | SSM parameter does not exist | `aws ssm put-parameter --name <path> --type SecureString --value <json>` |
| `SecretSyncedError` with property error | JSON key missing in SSM parameter | Verify SSM parameter JSON has expected keys |
| `ClusterSecretStore not ready` | AWS credentials invalid | Check `external-secrets-access-key` in kube-system |
| Secret exists but empty | Replicator source not annotated | Add `replication-allowed` annotations to source |
| Stale secret value | `refreshInterval` too long | Default is `1h`; reduce if needed |

## Common Replication Patterns

| Source | Source Namespace | Consumers | Purpose |
|--------|-----------------|-----------|---------|
| `cnpg-platform-superuser` | `database` | zipline, authelia | Shared DB superuser |
| `dragonfly-password` | `database` | immich, authelia | Shared cache password |
| `immich-database-app` | `database` | immich | Dedicated DB app credentials |
| `heartbeat-ping-url` | `kube-system` | monitoring | Health check URL |

## PrometheusRule Alerts for ExternalSecrets

Defined in `kubernetes/platform/config/monitoring/external-secrets-alerts.yaml`:

| Alert | Condition | Severity |
|-------|-----------|----------|
| `ExternalSecretSyncFailure` | Sync errors increasing over 5m | critical |
| `ExternalSecretNotReady` | Not ready for 10m+ | warning |
| `ClusterSecretStoreUnhealthy` | Store not ready for 5m | critical |

---

## Mechanism 1: secret-generator Templates

### Database Credentials Pattern

```yaml
# kubernetes/clusters/live/config/<app>/db-credentials.yaml
---
apiVersion: v1
kind: Secret
metadata:
  name: <app>-db-credentials
  namespace: <app-namespace>
  annotations:
    secret-generator.v1.mittwald.de/autogenerate: password
    secret-generator.v1.mittwald.de/encoding: hex
    secret-generator.v1.mittwald.de/length: "32"
type: kubernetes.io/basic-auth
stringData:
  username: <app>
```

Real examples: `kubernetes/clusters/live/config/authelia-prereqs/authelia-db-credentials.yaml`,
`kubernetes/clusters/live/config/zipline/zipline-db-credentials.yaml`

### Application Secret Pattern

```yaml
---
apiVersion: v1
kind: Secret
metadata:
  name: <app>-secret
  namespace: <app-namespace>
  annotations:
    secret-generator.v1.mittwald.de/autogenerate: CORE_SECRET
    secret-generator.v1.mittwald.de/length: "32"
    secret-generator.v1.mittwald.de/encoding: base64
data: {}
```

Real example: `kubernetes/clusters/live/config/zipline/secret.yaml`

### Platform-Level Secrets (with Replication)

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: cnpg-platform-superuser
  annotations:
    secret-generator.v1.mittwald.de/autogenerate: password
    secret-generator.v1.mittwald.de/length: "32"
    secret-generator.v1.mittwald.de/encoding: base64
    replicator.v1.mittwald.de/replication-allowed: "true"
    replicator.v1.mittwald.de/replication-allowed-namespaces: "zipline,authelia"
type: kubernetes.io/basic-auth
stringData:
  username: postgres
```

---

## Mechanism 2: ExternalSecret Templates

### Basic ExternalSecret

```yaml
# yaml-language-server: $schema=https://kubernetes-schemas.pages.dev/external-secrets.io/externalsecret_v1.json
---
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: <app>-credentials
spec:
  refreshInterval: 24h
  secretStoreRef:
    kind: ClusterSecretStore
    name: aws-ssm
  target:
    name: <app>-credentials
  data:
    - secretKey: api-token
      remoteRef:
        key: /homelab/kubernetes/${cluster_name}/<app>/api-token
```

### Multi-Key JSON Pattern

When an SSM parameter stores multiple keys as JSON (created by the `app-secrets` module),
extract individual properties with `remoteRef.property`:

```yaml
  data:
    - secretKey: LLDAP_KEY_SEED
      remoteRef:
        key: /homelab/kubernetes/live/lldap-secrets
        property: LLDAP_KEY_SEED
    - secretKey: LLDAP_JWT_SECRET
      remoteRef:
        key: /homelab/kubernetes/live/lldap-secrets
        property: LLDAP_JWT_SECRET
```

Real example: `kubernetes/clusters/live/config/authelia-prereqs/lldap-secrets.yaml`

### Templated ExternalSecret

For secrets that need transformation (e.g., generating a config file from credentials):

```yaml
  target:
    name: hardware-monitoring-credentials
    template:
      engineVersion: v2
      data:
        ipmi-config.yml: |
          modules:
            default:
              user: "{{ .ipmiUsername }}"
              pass: "{{ .ipmiPassword }}"
  data:
    - secretKey: ipmiUsername
      remoteRef:
        key: /homelab/kubernetes/${cluster_name}/ipmi-username
```

Real example: `kubernetes/platform/config/monitoring/hardware-monitoring-secrets.yaml`

**Placement:** Platform-wide secrets → `kubernetes/platform/config/<subsystem>/`.
Cluster-specific secrets → `kubernetes/clusters/<cluster>/config/<app>/`.

---

## Mechanism 3: app-secrets Module Template

```hcl
# infrastructure/units/<app>-secrets/terragrunt.hcl
include "root" { path = find_in_parent_folders("root.hcl") }
terraform { source = "../../../.././/modules/app-secrets" }

inputs = {
  name    = "<app>"
  secrets = {
    SECRET_KEY_1 = { length = 32, special = false }
    SECRET_KEY_2 = { length = 32, special = false }
  }
  ssm_parameter_path = "/homelab/kubernetes/live/<app>-secrets"
  local_backup_path  = pathexpand("~/.secrets/homelab/<app>-secrets.json")
}
```

Add to stack: `unit "<app>_secrets" { source = "../../units/<app>-secrets" }`, then
`task tg:apply-<stack>` (requires human approval). Create ExternalSecret using the
multi-key JSON pattern above.

---

## Mechanism 4: kubernetes-replicator Templates

**Source side** — add to the originating Secret:

```yaml
annotations:
  replicator.v1.mittwald.de/replication-allowed: "true"
  replicator.v1.mittwald.de/replication-allowed-namespaces: "app1,app2"
```

**Consumer side** — create an empty Secret referencing the source:

```yaml
---
apiVersion: v1
kind: Secret
metadata:
  name: <source-secret-name>
  namespace: <consumer-namespace>
  annotations:
    replicator.v1.mittwald.de/replicate-from: <source-namespace>/<source-secret-name>
data: {}
```
