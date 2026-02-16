# Secret Management

Four-tier secret management architecture providing flexibility across persistence requirements, generation methods, and cross-namespace sharing needs.

## Design Philosophy

Secrets are classified by two axes: **persistence** (does it survive cluster rebuilds?) and **origin** (randomly generated or externally sourced?). Each tier addresses a different combination, avoiding a one-size-fits-all approach that would either over-complicate simple cases or under-protect critical ones.

## Four-Tier Model

```
App needs a secret?
│
├─ Can it be randomly generated?
│   │
│   ├─ Must survive cluster rebuilds?
│   │   ├─ YES → Tier 3: app-secrets module (Terragrunt → SSM → ExternalSecret)
│   │   └─ NO  → Tier 1: secret-generator (in-cluster, auto-regenerates)
│   │
│   └─ Is it a database credential?
│       └─ Tier 1: secret-generator with type: kubernetes.io/basic-auth
│
├─ Must match an external value? (OAuth, cloud API, webhook)
│   └─ Tier 2: ExternalSecret → AWS SSM
│
└─ Shared across namespaces?
    └─ Tier 4: kubernetes-replicator (pull-based cross-namespace replication)
```

## Tier 1: secret-generator (Ephemeral, In-Cluster)

**Controller**: `mittwald/kubernetes-secret-generator`
**Persistence**: Ephemeral — regenerates on cluster rebuild
**Use Case**: Secrets that can be randomly generated and don't need external consistency

### How It Works

The controller watches for Secrets with `secret-generator.v1.mittwald.de/autogenerate` annotations. On creation, it populates the specified keys with random values. If the Secret already has values for those keys, it leaves them untouched.

### Patterns

```yaml
# Simple random password
apiVersion: v1
kind: Secret
metadata:
  name: my-app-secret
  annotations:
    secret-generator.v1.mittwald.de/autogenerate: password
    secret-generator.v1.mittwald.de/encoding: hex
    secret-generator.v1.mittwald.de/length: "32"
data: {}

# Database credentials (username + generated password)
apiVersion: v1
kind: Secret
metadata:
  name: my-db-credentials
  annotations:
    secret-generator.v1.mittwald.de/autogenerate: password
    secret-generator.v1.mittwald.de/encoding: hex
    secret-generator.v1.mittwald.de/length: "32"
type: kubernetes.io/basic-auth
stringData:
  username: myapp
```

### Current Users

| Secret | Namespace | Purpose |
|--------|-----------|---------|
| `grafana-admin` | monitoring | Grafana admin password |
| `garage-admin-token` | garage | Garage admin API token |
| `cnpg-platform-superuser` | database | PostgreSQL superuser (also replicated) |
| `dragonfly-password` | cache | Redis-compatible cache auth (also replicated) |
| `grafana-oidc-client-secret` | authelia | OAuth client secret (also replicated) |
| `authelia-db-credentials` | authelia | Authelia database password |
| `zipline-db-credentials` | zipline | Zipline database password |
| `zipline-secret` | zipline | Zipline application secret |

## Tier 2: ExternalSecret (Persistent, from AWS SSM)

**Operator**: External Secrets Operator (ESO)
**Store**: AWS SSM Parameter Store via ClusterSecretStore
**Persistence**: Persistent — survives cluster rebuilds
**Use Case**: Secrets that must come from outside the cluster or remain consistent across rebuilds

### Architecture

```
AWS SSM Parameter Store
       │
       ▼
ClusterSecretStore (aws-ssm)
  ├─ Auth: external-secrets-access-key (kube-system)
  │        Created by bootstrap Terraform module
  └─ Provider: AWS ParameterStore, us-east-2
       │
       ▼
ExternalSecret (per-namespace)
  └─ Creates target Secret with data from SSM
     Refresh interval: 1h - 24h depending on use
```

### SSM Path Conventions

```
/homelab/kubernetes/${cluster_name}/<secret-name>     # Cluster-specific
/homelab/kubernetes/shared/<secret-name>               # Shared across all clusters
```

### Patterns

| Pattern | Example | SSM Format |
|---------|---------|------------|
| Simple single-key | Cloudflare API token | JSON: `{"token": "<value>"}` |
| TLS certificate | Istio mesh CA, homelab CA | JSON: `{"tls.crt": "<pem>", "tls.key": "<pem>"}` |
| Templated config | IPMI credentials | Multiple keys → templated into config file |
| Webhook URL | Discord webhook | Plain string |
| S3 credentials | Longhorn backup | Separate keys: `access-key-id`, `secret-access-key` |

### Current ExternalSecrets

| Secret | Namespace | SSM Path | Purpose |
|--------|-----------|----------|---------|
| `cloudflare-api-token` | cert-manager | `/${cluster}/cloudflare-api-token` | DNS-01 challenges |
| `istio-mesh-root-ca` | cert-manager | `/shared/istio-mesh-ca` | Cross-cluster mTLS |
| `homelab-ingress-root-ca` | cert-manager | `/shared/homelab-ingress-ca` | Dev/integration ingress CA |
| `hardware-monitoring-credentials` | monitoring | `/${cluster}/ipmi-*` | IPMI exporter config |
| `alertmanager-discord-webhook` | monitoring | `/${cluster}/discord-webhook-secret` | Alert notifications |
| `flux-discord-webhook` | flux-system | `/${cluster}/discord-webhook-secret` | Flux notifications |
| `longhorn-s3-backup-credentials` | longhorn-system | `/${cluster}/longhorn-s3-backup/*` | S3 backup auth |
| `lldap-secrets` | authelia | `/live/lldap-secrets` | LLDAP encryption keys |

## Tier 3: app-secrets Module (Generated + Persistent)

**Provider**: Terragrunt + OpenTofu
**Storage**: AWS SSM Parameter Store (JSON SecureString)
**Persistence**: Persistent — survives cluster rebuilds
**Use Case**: Secrets that must be randomly generated AND persist across rebuilds

### Why This Tier Exists

Some secrets (like LLDAP's `KEY_SEED`) derive cryptographic material. If regenerated on cluster rebuild, all previously encrypted data becomes unreadable. These secrets must be:
1. Randomly generated (no human-chosen values)
2. Stored externally (survives cluster destruction)
3. Never regenerated after first creation

### How It Works

```
terragrunt apply (units/lldap-secrets/)
       │
       ├─ random_password resources generate values
       ├─ aws_ssm_parameter stores JSON SecureString
       │  (lifecycle: prevent_destroy + ignore_changes)
       └─ local_sensitive_file writes backup to ~/.secrets/
              │
              ▼
       ExternalSecret pulls individual keys
       via property field from JSON document
```

### Module Interface

```hcl
# infrastructure/units/lldap-secrets/terragrunt.hcl
inputs = {
  name = "lldap"
  secrets = {
    LLDAP_JWT_SECRET     = { length = 32, special = false }
    LLDAP_LDAP_USER_PASS = { length = 32, special = false }
    LLDAP_KEY_SEED       = { length = 32, special = false }
  }
  ssm_parameter_path = "/homelab/kubernetes/live/lldap-secrets"
  local_backup_path  = pathexpand("~/.secrets/homelab/lldap-secrets.json")
}
```

### Safety Features

- `prevent_destroy = true` on SSM parameter prevents accidental deletion
- `ignore_changes = [value]` prevents regeneration on subsequent applies
- Local backup at `~/.secrets/homelab/` with `0600` permissions for disaster recovery

## Tier 4: kubernetes-replicator (Cross-Namespace)

**Controller**: `mittwald/kubernetes-replicator`
**Mechanism**: Pull-based replication via annotations
**Use Case**: Sharing secrets across namespace boundaries

### How It Works

Source secrets opt-in to replication and whitelist target namespaces. Target namespaces create empty Secret resources that reference the source. The replicator controller watches both and keeps targets synchronized.

### Annotation Pairs

**Source** (origin namespace):
```yaml
annotations:
  replicator.v1.mittwald.de/replication-allowed: "true"
  replicator.v1.mittwald.de/replication-allowed-namespaces: "consumer1,consumer2"
```

**Replica** (target namespace):
```yaml
annotations:
  replicator.v1.mittwald.de/replicate-from: <source-namespace>/<source-secret-name>
```

### Current Replication Matrix

| Source Secret | Source Namespace | Consumers | Purpose |
|---------------|-----------------|-----------|---------|
| `cnpg-platform-superuser` | database | zipline, authelia | Shared DB superuser |
| `dragonfly-password` | cache | immich, authelia | Cache authentication |
| `immich-database-app` | database | immich | Dedicated DB credentials |
| `grafana-oidc-client-secret` | authelia | monitoring | Grafana OAuth |
| `heartbeat-ping-url` | kube-system | monitoring | Health check webhook |

## Secret Placement Guide

| Scope | Location | Example |
|-------|----------|---------|
| Platform-wide | `kubernetes/platform/config/<subsystem>/` | DB superuser, Dragonfly password, CA certs |
| Cluster-specific | `kubernetes/clusters/<cluster>/config/<subsystem>/` | LLDAP keys, DB credentials, replicator targets |
| Bootstrap-created | Infrastructure modules | ESO credentials, heartbeat URL, Flux token |

## Bootstrap Requirements

These SSM parameters must exist before a cluster can function:

| SSM Path | Purpose |
|----------|---------|
| `/homelab/kubernetes/external-secrets/access-key-id` | ESO AWS credentials |
| `/homelab/kubernetes/external-secrets/secret-access-key` | ESO AWS credentials |
| `/homelab/kubernetes/${cluster}/cloudflare-api-token` | DNS challenge auth |
| `/homelab/kubernetes/${cluster}/discord-webhook-secret` | Alert notifications |
| `/homelab/kubernetes/${cluster}/ipmi-username` | Hardware monitoring |
| `/homelab/kubernetes/${cluster}/ipmi-password` | Hardware monitoring |
| `/homelab/kubernetes/${cluster}/longhorn-s3-backup/*` | S3 backup auth |
| `/homelab/kubernetes/shared/istio-mesh-ca` | Cross-cluster mTLS |
| `/homelab/kubernetes/shared/homelab-ingress-ca` | Shared ingress CA |

## Key Design Decisions

1. **In-cluster generation preferred over external**: Tier 1 (secret-generator) is the default choice. Only escalate to Tier 2/3 when persistence or external sourcing is required. This minimizes external dependencies.
2. **Pull-based replication over push**: Tier 4 uses pull-based annotations where the consumer declares what it needs, rather than the source pushing to consumers. This preserves least-privilege — the source only whitelists, the consumer explicitly opts in.
3. **JSON SecureString for multi-key secrets**: Tier 3 stores all keys for an app as a single JSON document in SSM, extracted by ExternalSecret's `property` field. This avoids SSM parameter sprawl.
4. **Refresh intervals by sensitivity**: TLS certificates refresh every 24h, API tokens every 1h. Faster refresh means faster recovery from SSM rotation.
5. **No secrets in git**: All four tiers keep secret values out of the repository. Git contains only Secret manifests with empty `data: {}` or annotation-driven generation.

## Related Resources

- Operational guide: `.claude/skills/secrets/SKILL.md`
- Platform secrets reference: `kubernetes/platform/CLAUDE.md` (Secrets Management section)
- ExternalSecret store: `kubernetes/platform/config/secrets/cluster-secret-store.yaml`
- app-secrets module: `infrastructure/modules/app-secrets/`
