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
| `tag-validated-artifact.yaml` | status event (commit status) | Promote validated artifact to live |
| `renovate.yaml` | Scheduled (hourly) | Dependency update automation |
| `label-sync.yaml` | Scheduled/manual | Sync GitHub labels |
| `check-version-holds.yaml` | Weekly/push (version-holds.yaml)/manual | Monitor upstream issues for held-back versions |

> For the full OCI artifact promotion pipeline (flow, artifact tagging, debugging, manual promotion), invoke the `promotion-pipeline` skill.

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

1. **Resolve version**: Queries GHCR for latest stable tag, bumps patch, increments RC number
2. **Push artifact**: `flux push artifact ... :X.Y.Z-rc.N`
3. **Tag**: Adds `sha-<short>` and `integration-<short>` tags

### tag-validated-artifact.yaml

Triggers on `status` event (GitHub commit status posted by Flux's `github` Provider):

1. **Filter**: Only runs on `state == 'success'` with context prefix `kustomization/platform/`
2. **Resolve**: Extracts short SHA from commit, finds `integration-<sha>` artifact, extracts RC tag
3. **Derive stable**: Strips `-rc.N` suffix (e.g., `0.1.146-rc.3` → `0.1.146`)
4. **Tag**: Adds `validated-<sha>` and stable semver tags

---

## Cross-References

| Document | Focus |
|----------|-------|
| [CLAUDE.md](../CLAUDE.md) | Promotion pipeline overview, principles |
| [kubernetes/clusters/CLAUDE.md](../kubernetes/clusters/CLAUDE.md) | Per-cluster OCIRepository configuration |
| [kubernetes/platform/CLAUDE.md](../kubernetes/platform/CLAUDE.md) | Flux patterns, ResourceSets |
| `promotion-pipeline` skill | End-to-end pipeline tracing, artifact tags, debugging, manual promotion, rollback |
