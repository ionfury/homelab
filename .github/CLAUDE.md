# GitHub Workflows - Claude Reference

GitHub Actions workflows that implement CI/CD for the homelab infrastructure, including the OCI artifact promotion pipeline.

For core principles and deployment philosophy, see [CLAUDE.md](../CLAUDE.md).

---

## Workflow Inventory

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `kubernetes-validate.yaml` | PR (kubernetes/ changes) | Validate K8s manifests, schemas, deprecations |
| `infrastructure-validate.yaml` | PR (infrastructure/ changes) | Format checks, module tests |
| `renovate-validate.yaml` | PR (renovate config) | Validate Renovate configuration |
| `build-platform-artifact.yaml` | Push to main (kubernetes/) | Build OCI artifact for promotion |
| `tag-validated-artifact.yaml` | repository_dispatch | Promote validated artifact to live |
| `renovate.yaml` | Scheduled (hourly) | Dependency update automation |
| `label-sync.yaml` | Scheduled/manual | Sync GitHub labels |

---

## OCI Artifact Promotion Pipeline

The promotion pipeline uses OCI artifacts for immutable, auditable deployments.

### Pipeline Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                         PR merged to main                           │
└─────────────────────────────────┬───────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│  build-platform-artifact.yaml                                       │
│  ├─ flux push artifact → ghcr.io/.../platform:0.1.0-rc.N           │
│  ├─ flux tag artifact → sha-<short-sha>                            │
│  └─ flux tag artifact → integration-<short-sha>                    │
└─────────────────────────────────┬───────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Integration Cluster                                                │
│  ├─ OCIRepository polls for semver ">= 0.0.0-0" (includes RCs)     │
│  ├─ Detects new 0.1.0-rc.N artifact                                │
│  └─ Flux reconciles platform                                        │
└─────────────────────────────────┬───────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Canary-Checker Validation                                          │
│  ├─ Monitors Kustomization health                                   │
│  ├─ Runs platform smoke tests                                       │
│  └─ On success: Alert triggers repository_dispatch                  │
└─────────────────────────────────┬───────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│  tag-validated-artifact.yaml                                        │
│  └─ flux tag artifact → validated-<short-sha>                      │
└─────────────────────────────────┬───────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Live Cluster                                                       │
│  ├─ OCIRepository polls for "validated-*" pattern                   │
│  ├─ Detects new validated-<sha> tag                                │
│  └─ Flux reconciles platform (production deployment)                │
└─────────────────────────────────────────────────────────────────────┘
```

### Artifact Tagging Strategy

| Tag | Created By | Purpose |
|-----|------------|---------|
| `0.1.0-rc.N` | build workflow | Semver for OCIRepository polling |
| `sha-<short>` | build workflow | Immutable reference to commit |
| `integration-<short>` | build workflow | Marks artifact for integration |
| `validated-<short>` | tag workflow | Marks artifact for production |

---

## Source Types by Cluster

| Cluster | Source Type | Semver/Pattern | Rationale |
|---------|-------------|----------------|-----------|
| `dev` | GitRepository | N/A | Fast iteration, no build step |
| `integration` | OCIRepository | `>= 0.0.0-0` | Accepts RC versions |
| `live` | OCIRepository | `validated-*` | Only validated artifacts |

### Why Different Sources?

**Dev cluster** uses GitRepository because:
- Faster feedback loop (no build wait)
- Easy to test WIP changes
- Acceptable risk for dev environment

**Integration/Live clusters** use OCIRepository because:
- **Immutable artifacts**: Same bits deployed everywhere
- **Auditability**: Exact artifact version in GHCR
- **Promotion gates**: Validation must pass before live

---

## Debugging Guide

### Artifact Stuck in Integration?

```
Is the artifact in GHCR?
│
├─ NO → Check build-platform-artifact.yaml run
│       └─ Did the workflow trigger?
│           ├─ NO → Was kubernetes/ modified?
│           └─ YES → Check workflow logs for push errors
│
└─ YES → Is OCIRepository seeing it?
         └─ kubectl get ocirepository -n flux-system
             ├─ NO match → Check semver constraint
             └─ Match found → Check Kustomization status
                 └─ kubectl get kustomization -n flux-system
```

### Validation Not Triggering Promotion?

```bash
# Check canary-checker status
kubectl get canaries -n canary-checker

# Check Alert configuration
kubectl get alerts -n flux-system

# Check Provider (GitHub) configuration
kubectl get providers -n flux-system

# Check if Alert fired
kubectl describe alert canary-success -n flux-system
```

### Tracing an Artifact

```bash
# 1. Find artifact in GHCR
flux list artifact oci://ghcr.io/<repo>/platform

# 2. Check tags
flux list artifact oci://ghcr.io/<repo>/platform | grep <sha>

# 3. Check which cluster has it
kubectl get ocirepository -n flux-system -o yaml | grep -A5 "artifact"

# 4. Check reconciliation status
flux get kustomizations -A
```

### Common Failure Modes

| Symptom | Cause | Fix |
|---------|-------|-----|
| Build succeeds but integration doesn't update | Semver not matching `>= 0.0.0-0` | Check OCIRepository spec |
| Validation passes but live doesn't update | `validated-*` tag not applied | Check tag-validated workflow |
| `repository_dispatch` not received | GitHub token missing `repo` scope | Check Provider secret |
| Artifact push fails | GHCR auth issue | Check `GITHUB_TOKEN` permissions |

### Manual Promotion (Emergency)

If automatic promotion fails, manually tag:

```bash
# Authenticate
echo $GITHUB_TOKEN | docker login ghcr.io -u $GITHUB_USER --password-stdin

# Tag manually
flux tag artifact \
  oci://ghcr.io/<repo>/platform:integration-<sha> \
  --tag validated-<sha>
```

### Rollback Procedure

```bash
# Find previous validated artifact
flux list artifact oci://ghcr.io/<repo>/platform | grep validated

# Re-tag previous artifact as latest validated
flux tag artifact \
  oci://ghcr.io/<repo>/platform:validated-<old-sha> \
  --tag validated-<old-sha>-rollback

# Or: Patch OCIRepository to pin specific version
kubectl patch ocirepository platform -n flux-system \
  --type=merge \
  -p '{"spec":{"ref":{"tag":"validated-<old-sha>"}}}'
```

---

## Workflow Details

### kubernetes-validate.yaml

Runs on PRs touching `kubernetes/`:

1. **Lint**: yamllint on all YAML
2. **Expand**: flux-operator expands ResourceSets
3. **Build**: kustomize build with variable substitution
4. **Template**: Helm template all charts
5. **Validate**: kubeconform schema validation
6. **Deprecations**: pluto checks for removed APIs

### infrastructure-validate.yaml

Runs on PRs touching `infrastructure/`:

1. **Format**: terragrunt hclfmt + tofu fmt
2. **Test**: tofu test for modified modules

### build-platform-artifact.yaml

Triggers on push to main (kubernetes/ changes):

```yaml
# Key steps
flux push artifact \
  oci://ghcr.io/${{ github.repository }}/platform:${SEMVER} \
  --path=. \
  --source="https://github.com/${{ github.repository }}" \
  --revision="${{ github.ref_name }}@sha1:${{ github.sha }}"

flux tag artifact ... --tag integration-${SHORT_SHA}
```

### tag-validated-artifact.yaml

Triggers on `repository_dispatch` from canary-checker:

```yaml
# Validates SHA format and tags
flux tag artifact \
  "oci://ghcr.io/.../platform:integration-${SHA}" \
  --tag "validated-${SHA}"
```

---

## Cross-References

| Document | Focus |
|----------|-------|
| [CLAUDE.md](../CLAUDE.md) | Promotion pipeline overview, principles |
| [kubernetes/clusters/CLAUDE.md](../kubernetes/clusters/CLAUDE.md) | Per-cluster OCIRepository configuration |
| [kubernetes/platform/CLAUDE.md](../kubernetes/platform/CLAUDE.md) | Flux patterns, ResourceSets |
