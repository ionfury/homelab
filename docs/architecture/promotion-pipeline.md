# OCI Artifact Promotion Pipeline

Immutable OCI artifact-based promotion from PR merge through integration validation to live deployment, replacing branch-based GitOps with artifact-based GitOps.

## Design Philosophy

The previous git-branch approach only protected version changes, not configuration changes. By packaging the entire `kubernetes/` directory as an immutable OCI artifact, every configuration change — Helm values, network policies, alert rules — goes through the same promotion pipeline with integration validation before reaching production.

## Promotion Flow

```
PR merged to main
       │
       ▼
┌──────────────────────────┐
│  build-platform-artifact │  GHA packages kubernetes/ as OCI artifact
│  Tags: X.Y.Z-rc.N       │  Pushes to ghcr.io/<org>/<repo>/platform
│        sha-<short>       │
│        integration-<sha> │
└──────────┬───────────────┘
           │
           ▼
┌──────────────────────────┐
│  Integration cluster     │  OCIRepository polls for >= 0.0.0-0
│  Flux reconciles         │  (includes pre-releases)
│  platform Kustomization  │
└──────────┬───────────────┘
           │
           ▼
┌──────────────────────────┐
│  canary-checker           │  Platform health validation suite:
│  platform-validation      │  HTTP, DNS, TCP, Kubernetes checks
└──────────┬───────────────┘
           │
           ▼
┌──────────────────────────┐
│  Flux Alert fires        │  validation-success Alert watches
│  → GitHub Provider       │  platform Kustomization reconciliation
│  → Commit status posted  │  Posts status with kustomization/platform/* context
└──────────┬───────────────┘
           │
           ▼
┌──────────────────────────┐
│  tag-validated-artifact  │  GHA triggered by status event
│  Tags: validated-<sha>   │  Strips RC suffix for stable semver
│        X.Y.Z (stable)    │
└──────────┬───────────────┘
           │
           ▼
┌──────────────────────────┐
│  Live cluster            │  OCIRepository polls for >= 0.0.0
│  Flux reconciles         │  (stable only, excludes pre-releases)
└──────────────────────────┘
```

## Tagging Strategy

Each artifact accumulates tags through its lifecycle:

| Tag | Created By | Purpose |
|-----|-----------|---------|
| `X.Y.Z-rc.N` | build workflow | Pre-release semver for integration OCIRepository polling |
| `sha-<short>` | build workflow | Immutable git commit reference for audit trail |
| `integration-<short>` | build workflow | Identifies artifact for integration deployment |
| `validated-<short>` | tag workflow | Traceability — proves artifact passed integration |
| `X.Y.Z` | tag workflow | Stable semver for live OCIRepository polling |

### Version Numbering

1. Build workflow queries GHCR for latest stable semver tag (e.g., `0.1.145`)
2. Bumps patch version: `0.1.146`
3. Finds highest existing RC for that version and increments: `0.1.146-rc.3`
4. After validation, strips RC suffix for stable: `0.1.146`

## Cluster Source Configuration

| Cluster | Source Type | Semver Constraint | Receives |
|---------|-----------|-------------------|----------|
| `dev` | GitRepository | n/a (branch-based) | Direct git sync for experimentation |
| `integration` | OCIRepository | `>= 0.0.0-0` | Pre-releases (RC builds) |
| `live` | OCIRepository | `>= 0.0.0` | Stable releases only |

The semver constraint is the key differentiator: the `-0` suffix in integration's constraint includes pre-release versions per semver spec, while live's constraint excludes them.

## GitHub Workflows

### build-platform-artifact.yaml

**Trigger**: Push to main (kubernetes/** changes) or manual dispatch.

Resolves next RC version by querying GHCR, packages `kubernetes/` directory with `flux push artifact`, and applies three tags (semver RC, sha, integration).

### tag-validated-artifact.yaml

**Trigger**: GitHub `status` event with context prefix `kustomization/platform/` and state `success`.

Includes an **idempotency guard** — checks if artifact already has `validated-<sha>` tag before proceeding (the Flux Alert fires on every reconciliation cycle, roughly every 10 minutes).

### kubernetes-validate.yaml

**Trigger**: Pull requests. Runs cluster-independent validation (lint, ResourceSets, Helm, schema) plus per-cluster validation.

## Validation Gate

The `platform-validation` Canary in the integration cluster performs comprehensive health checks before promotion:

| Check Type | Target | Purpose |
|-----------|--------|---------|
| HTTP | Kubernetes API `/healthz` | API server health |
| HTTP | Grafana `/api/health` | Monitoring stack operational |
| DNS | `kubernetes.default.svc.cluster.local` | CoreDNS resolution |
| TCP | `platform-pooler-rw.database.svc:5432` | Database connectivity |
| Kubernetes | Flux pods Ready + Running | GitOps system healthy |
| Kubernetes | Longhorn manager healthy | Storage system operational |
| Kubernetes | CNPG operator healthy | Database operator operational |
| Kubernetes | cert-manager healthy | Certificate management operational |
| Kubernetes | Gateway certificates valid | TLS termination working |

If any check fails, the `CanaryCheckFailure` alert fires (critical, 2m) and promotion does not proceed.

## Notification Chain

```
Flux platform Kustomization → Ready
       │
       ▼
Flux Alert (validation-success)
       │
       ▼
Flux Provider (github-dispatch, type: github)
       │  Posts commit status via GitHub API
       │  Context: kustomization/platform/<uid-prefix>
       │  State: success
       ▼
GitHub fires status event
       │
       ▼
tag-validated-artifact workflow triggers
```

The Provider requires a GitHub token with `statuses:write` permission, stored in the `flux-system` Secret created during bootstrap.

## Infrastructure Configuration

The bootstrap Terraform module configures Flux source type per cluster:

```hcl
# infrastructure/modules/config/main.tf
oci_config = {
  dev         = { source_type = "git",  semver = "" }
  integration = { source_type = "oci",  semver = ">= 0.0.0-0" }
  live        = { source_type = "oci",  semver = ">= 0.0.0" }
}
```

OCI clusters use a separate Flux instance template (`instance-oci.yaml.tftpl`) that patches the OCIRepository with the semver constraint via a Kustomize post-build patch.

## Safety Mechanisms

1. **Immutable artifacts**: OCI artifacts are content-addressed. Tags are pointers, but the content cannot be modified after push.
2. **Semver filtering**: Integration accepts pre-releases (`-0` suffix), live accepts only stable. No manual tag manipulation can skip this.
3. **Idempotency guard**: The tag workflow checks for existing `validated-<sha>` tag before acting, preventing duplicate promotions.
4. **Context-based filtering**: The tag workflow only processes status events with `kustomization/platform/` context prefix, ignoring unrelated reconciliations.
5. **Canary validation**: Multiple health check types must all pass before promotion. A single failing check blocks the pipeline.

## Manual Promotion (Emergency)

```bash
# Authenticate to GHCR
echo $GITHUB_TOKEN | docker login ghcr.io -u $GITHUB_USER --password-stdin

# Find the integration artifact
flux list artifact oci://ghcr.io/<org>/<repo>/platform | grep integration

# Tag for promotion
flux tag artifact oci://ghcr.io/<org>/<repo>/platform:integration-<sha> --tag validated-<sha>
flux tag artifact oci://ghcr.io/<org>/<repo>/platform:integration-<sha> --tag X.Y.Z
```

## Common Failure Modes

| Symptom | Likely Cause | Investigation |
|---------|-------------|---------------|
| Integration doesn't update after merge | OCIRepository semver mismatch | Check kustomize patch applies `>= 0.0.0-0` |
| Validation passes but live doesn't update | `validated-*` tag not applied | Check tag-validated workflow logs for idempotency skip |
| Commit status not posted | Token lacks permissions | Verify `flux-system` Secret has `statuses:write` |
| Artifact stuck in integration | Canary check failing | `kubectl get canaries -n monitoring` and check metrics |
| Multiple RCs for same version | Normal behavior | Each push to main increments the RC number |

## Related Resources

- Build workflow: `.github/workflows/build-platform-artifact.yaml`
- Validation workflow: `.github/workflows/tag-validated-artifact.yaml`
- Canary health checks: `kubernetes/platform/config/canary-checker/platform-health.yaml`
- Flux notifications: `kubernetes/platform/config/flux-notifications/`
- Design document: `docs/plans/oci-artifact-promotion.md`
