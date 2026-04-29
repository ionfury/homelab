# OCI Artifact Promotion Pipeline

Immutable OCI artifact-based deployment from PR merge directly to live, replacing branch-based GitOps with artifact-based GitOps.

## Design Philosophy

The previous git-branch approach only protected version changes, not configuration changes. By packaging the entire `kubernetes/` directory as an immutable OCI artifact, every configuration change — Helm values, network policies, alert rules — goes through the same build pipeline. Artifacts are tagged as stable on build and deployed directly to live, with canary-checker providing post-deploy health validation.

## Promotion Flow

```
PR merged to main
       │
       ▼
┌──────────────────────────┐
│  build-platform-artifact │  GHA packages kubernetes/ as OCI artifact
│  Tags: X.Y.Z (stable)   │  Pushes to ghcr.io/<org>/<repo>/platform
│        sha-<short>       │  Creates GitHub Release
│        validated-<short> │
└──────────┬───────────────┘
           │
           ▼
┌──────────────────────────┐
│  Live cluster            │  OCIRepository polls for >= 0.0.0
│  Flux reconciles         │  (stable releases)
│  platform Kustomization  │
└──────────┬───────────────┘
           │
           ▼
┌──────────────────────────┐
│  canary-checker          │  Platform health validation suite:
│  platform-validation     │  HTTP, DNS, TCP, Kubernetes checks
│  (post-deploy signal)    │  Fires alert if unhealthy
└──────────────────────────┘
```

## Tagging Strategy

Each artifact receives all tags at build time:

| Tag | Purpose |
|-----|---------|
| `X.Y.Z` | Stable semver for live OCIRepository polling |
| `sha-<short>` | Immutable git commit reference for audit trail |
| `validated-<short>` | Compatibility tag for live cluster's `tag_pattern` filter |

### Version Numbering

1. Build workflow queries GHCR for latest stable semver tag (e.g., `0.1.145`)
2. Bumps patch version: `0.1.146`
3. Tags artifact and creates GitHub Release `v0.1.146`

## Cluster Source Configuration

| Cluster | Source Type | Semver Constraint | Receives |
|---------|-----------|-------------------|----------|
| `dev` | GitRepository | n/a (branch-based) | Direct git sync for experimentation |
| `live` | OCIRepository | `>= 0.0.0` | Stable releases |

## GitHub Workflows

### build-platform-artifact.yaml

**Trigger**: Push to main (kubernetes/** changes) or manual dispatch.

Resolves next stable version by querying GHCR, packages `kubernetes/` directory with `flux push artifact`, applies tags (stable semver, sha, validated), and creates a GitHub Release.

### kubernetes-validate.yaml

**Trigger**: Pull requests. Runs cluster-independent validation (lint, ResourceSets, Helm, schema) plus per-cluster validation.

## Post-Deploy Validation

The `platform-validation` Canary on live performs health checks after each deployment:

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

If any check fails, the `CanaryCheckFailure` alert fires (critical, 2m) to Discord. This is a **rollback signal**, not a promotion gate.

## Infrastructure Configuration

The bootstrap Terraform module configures Flux source type per cluster:

```hcl
# infrastructure/modules/config/main.tf
oci_config = {
  dev  = { source_type = "git",  semver = "" }
  live = { source_type = "oci",  semver = ">= 0.0.0" }
}
```

OCI clusters use a separate Flux instance template (`instance-oci.yaml.tftpl`) that patches the OCIRepository with the semver constraint via a Kustomize post-build patch.

## Safety Mechanisms

1. **Immutable artifacts**: OCI artifacts are content-addressed. Tags are pointers, but the content cannot be modified after push.
2. **Semver filtering**: Live accepts only stable semver (no pre-release suffix). No manual tag manipulation can bypass this.
3. **PR validation**: `kubernetes-validate.yaml` runs lint, schema validation, ResourceSet expansion, and Helm templating on every PR before merge.
4. **Canary validation**: Post-deploy health checks on live catch runtime issues and alert via Discord.
5. **Flux timeout**: HelmRelease/Kustomization timeouts prevent Flux from rolling forward on failed reconciliations — existing pods keep running.

## Rollback

If a deployment causes issues on live:

1. **Automatic**: Flux keeps last known good state if reconciliation times out
2. **Revert commit**: Revert on main → new OCI artifact builds → live picks up the fix
3. **Emergency tag**: Manually re-tag a known-good artifact as the latest stable version:
   ```bash
   echo $GITHUB_TOKEN | docker login ghcr.io -u $GITHUB_USER --password-stdin
   flux tag artifact oci://ghcr.io/<org>/<repo>/platform:sha-<known-good> --tag <next-version>
   ```

## Common Failure Modes

| Symptom | Likely Cause | Investigation |
|---------|-------------|---------------|
| Live doesn't update after merge | Build workflow failed | Check `build-platform-artifact` run logs |
| Live shows old version | OCIRepository not polling | `flux get source oci -A --context live` |
| Artifact built but no release | GitHub Release step failed | Check workflow logs, verify `contents: write` permission |
| Canary alert firing after deploy | Broken config deployed | Check canary check details, consider revert |

## Related Resources

- Build workflow: `.github/workflows/build-platform-artifact.yaml`
- Canary health checks: `kubernetes/platform/config/canary-checker/platform-health.yaml`
- Flux notifications: `kubernetes/platform/config/flux-notifications/`
