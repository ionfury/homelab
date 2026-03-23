---
name: secrets
description: |
  Secret management patterns for the Kubernetes homelab platform.
  Covers secret-generator, ExternalSecret, app-secrets Terragrunt module,
  and cross-namespace replication via kubernetes-replicator.

  Use when: (1) Adding secrets for a new application, (2) Deciding between secret-generator
  and ExternalSecret, (3) Configuring cross-namespace secret replication, (4) Creating
  persistent secrets via the app-secrets Terragrunt module, (5) Debugging secret sync failures.

  Triggers: "secret", "ExternalSecret", "secret-generator", "aws ssm", "parameter store",
  "kubernetes-replicator", "replicate secret", "app-secrets", "persistent secret",
  "cross-namespace secret", "secret not syncing", "ClusterSecretStore"
user-invocable: false
---

# Secrets Management

Four mechanisms exist for provisioning secrets. See [reference.md](reference.md) for the
mechanism comparison table and annotation reference.

## Decision Tree

```
App needs a secret?
│
├─ Can it be randomly generated? (password, API key, token)
│   │
│   ├─ Does it need to survive cluster rebuilds?
│   │   ├─ YES (e.g., encryption key seed, LDAP key)
│   │   │   └─ Use app-secrets Terragrunt module + ExternalSecret
│   │   └─ NO (e.g., session secret, internal API key)
│   │       └─ Use secret-generator annotation
│   │
│   └─ Is it a database credential?
│       └─ Use secret-generator with type: kubernetes.io/basic-auth
│
├─ Must match an external value? (OAuth, cloud API, webhook URL)
│   └─ Use ExternalSecret → AWS SSM
│
├─ Shared across namespaces? (DB superuser, Dragonfly password)
│   └─ Use kubernetes-replicator annotations
│
└─ Unclear?
    └─ AskUserQuestion: "Can this secret be randomly generated,
       or must it match a specific external value?"
```

---

## Mechanism 1: secret-generator (Ephemeral, In-Cluster)

The `mittwald/kubernetes-secret-generator` controller watches for annotated Secrets and
auto-populates them with random values. Preferred for secrets that do not need to persist
across cluster rebuilds.

Template: see [reference.md](reference.md#mechanism-1-secret-generator-templates)

---

## Mechanism 2: ExternalSecret (Persistent, from AWS SSM)

ESO pulls values from AWS SSM Parameter Store via the `aws-ssm` ClusterSecretStore at
`kubernetes/platform/config/secrets/cluster-secret-store.yaml` (region: us-east-2).

**SSM path convention:** `/homelab/kubernetes/${cluster_name}/<app-or-secret-name>`

Template: see [reference.md](reference.md#mechanism-2-externalsecret-templates)

---

## Mechanism 3: app-secrets Terragrunt Module (Generated + Persistent)

For secrets that must be randomly generated AND survive cluster rebuilds. OpenTofu generates
random values and stores them as a JSON SecureString in AWS SSM. An ExternalSecret then pulls
individual keys.

`lifecycle.prevent_destroy = true` protects the SSM parameter. `lifecycle.ignore_changes = [value]`
prevents re-generating on subsequent applies. Local backup written to `~/.secrets/homelab/<app>-secrets.json`.

Workflow: create unit → add to stack → apply → create ExternalSecret using the multi-key JSON
pattern from Mechanism 2. Real example: `infrastructure/units/lldap-secrets/terragrunt.hcl`.

Template: see [reference.md](reference.md#mechanism-3-app-secrets-module-template)

---

## Mechanism 4: kubernetes-replicator (Cross-Namespace)

Copies Secrets from one namespace to another. Used when a shared resource generates a secret
that consumer namespaces need. Add replication annotations to the source Secret, then create
an empty consumer Secret referencing it. Add both files to their respective `kustomization.yaml`.

Template: see [reference.md](reference.md#mechanism-4-kubernetes-replicator-templates)

---

## Three-Tier Pattern (Exemplar: Authelia)

`kubernetes/clusters/live/config/authelia-prereqs/` demonstrates all three types together:

| File | Mechanism | Purpose |
|------|-----------|---------|
| `lldap-secrets.yaml` | ExternalSecret (app-secrets module) | Persistent LLDAP encryption keys |
| `authelia-db-credentials.yaml` | secret-generator | Ephemeral DB password |
| `cnpg-superuser-replica.yaml` | kubernetes-replicator | Replicated from database namespace |
| `dragonfly-secret-replication.yaml` | kubernetes-replicator | Replicated from database namespace |

---

## Debugging

Run `scripts/check-secret-sync.sh <name> <namespace>` for the full status check sequence.

To verify an SSM parameter exists:
```bash
aws ssm get-parameter --name "/homelab/kubernetes/<cluster>/<secret>" --with-decryption
```

See [reference.md](reference.md) for common failure causes and alert definitions.

---

## Cross-References

| Document | Relevance |
|----------|-----------|
| [kubernetes/platform/CLAUDE.md](../../../kubernetes/platform/CLAUDE.md) | Secrets management overview, SSM parameters for bootstrap |
| [deploy-app skill](../deploy-app/SKILL.md) | Secrets decision tree for new deployments |
| [cnpg-database skill](../cnpg-database/SKILL.md) | Database credential chain |
| [terragrunt skill](../terragrunt/SKILL.md) | Infrastructure operations for app-secrets module |
