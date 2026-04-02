# GitHub Workflows - Claude Reference

GitHub Actions workflows that implement CI/CD for the homelab infrastructure, including the OCI artifact promotion pipeline.

For core principles and deployment philosophy, see [CLAUDE.md](../CLAUDE.md).

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
