---
name: promotion-pipeline
description: |
  Direct build-to-live OCI artifact pipeline from PR merge to cluster deployment.

  Use when: (1) Tracing why a change has not reached a cluster, (2) Understanding the build/deploy lifecycle,
  (3) Performing rollback or emergency re-tagging, (4) Investigating GitHub Actions workflow failures,
  (5) Checking OCI artifact tags in GHCR, (6) Interpreting canary-checker post-deploy validation.

  Triggers: "promotion", "pipeline", "artifact", "oci", "live deploy",
  "not deploying", "ghcr", "build artifact", "tag validated",
  "canary-checker", "rollback", "semver", "github release",
  "promotion pipeline", "why isn't live updating"
user-invocable: false
---

# Promotion Pipeline

The homelab uses immutable OCI artifacts for deployment. Since PR #858 the pipeline is **direct build-to-live**: artifacts are tagged as stable at build time and deployed straight to live, with canary-checker providing a post-deploy health signal (not a promotion gate). There is no integration validation stage.

## Pipeline Overview

```
PR merged to main (kubernetes/ changed)
       |
       v
build-platform-artifact.yaml (GHA)
  - Queries GHCR for highest stable X.Y.Z tag, bumps patch
  - Pushes OCI artifact tagged X.Y.Z (stable, no RC suffix)
  - Adds tags: sha-<short>, validated-<short>
  - Creates GitHub Release vX.Y.Z
       |
       v
Live Cluster (and integration, in parallel)
  - Live OCIRepository polls GHCR with semver ">= 0.0.0"
  - Integration polls ">= 0.0.0-0" — same artifacts, not a gate
  - Flux reconciles platform Kustomization
       |
       v
canary-checker (post-deploy signal)
  - platform-validation Canary runs health checks continuously
  - CanaryCheckFailure alert fires to Discord if unhealthy
  - This is a ROLLBACK SIGNAL, not a promotion gate
```

See [references/pipeline-reference.md](references/pipeline-reference.md) for artifact tagging strategy, source types, failure modes, and key files.

## Tracing a Change End-to-End

Use `--context <cluster>` for cluster-specific kubectl/flux commands. The build triggers on push to `main` when `kubernetes/**` files change only.

| Stage | Check | Command |
|-------|-------|---------|
| 1. GHA Build | Did build workflow trigger? | `gh run list --workflow=build-platform-artifact.yaml --limit=5` |
| 1. GHA Build | View logs | `gh run view <run-id> --log` |
| 2. GHCR | List/find artifacts | `flux list artifact oci://ghcr.io/<owner>/homelab/platform --limit=10 \| grep <short-sha>` |
| 2. GHCR | GitHub Release created? | `gh release list --limit=5` |
| 3. Live | OCIRepository status | `kubectl --context live get ocirepository -n flux-system -o wide` |
| 3. Live | Current deployed version | `kubectl --context live get ocirepository flux-system -n flux-system -o jsonpath='{.status.artifact.revision}'` |
| 3. Live | Kustomization status | `kubectl --context live get kustomization platform -n flux-system` |
| 3. Live | Force reconcile | `flux --context live reconcile source oci flux-system -n flux-system` |
| 4. Health | Canary status | `kubectl --context live get canaries -n monitoring` |
| 4. Health | HelmRelease health | `flux --context live get helmreleases -A` |

## Debugging: Live Not Updating

```
Artifact in GHCR with stable X.Y.Z tag?
+-- NO  --> build workflow: did it trigger (kubernetes/** paths filter)?
            GITHUB_TOKEN packages:write? "flux push artifact" errors?
+-- YES --> Live OCIRepository seeing the tag?
    +-- NO  --> semver constraint ">= 0.0.0"? tag higher than current?
                Check .status.conditions for errors
                flux --context live reconcile source oci flux-system -n flux-system
    +-- YES --> Kustomization reconciling?
        +-- NO  --> kubectl --context live describe kustomization platform -n flux-system
                    dependency/schema errors?
        +-- YES --> flux --context live get helmreleases -A; health checks blocking rollout?
```

## Canary-Checker Validation

The `platform-validation` Canary in `monitoring` runs health checks (Kubernetes API, Flux pods, DNS, database, storage, cert-manager, gateway certs) continuously after deploy.

```bash
# Check canary status
kubectl --context live get canaries -n monitoring
kubectl --context live describe canary platform-validation -n monitoring
# canary_check{name="platform-validation"} == 0 means healthy
```

Alerts: `CanaryCheckFailure` (critical, 2m) and `CanaryCheckHighFailureRate` (>20% over 15m, warning). A firing canary alert after a deploy means consider reverting — it does not block or roll back anything automatically.

## Rollback Procedure

**Option 1 — Revert the PR** (safest): revert on main, a new higher-versioned artifact builds and live picks it up naturally.

**Option 2 — Re-tag a known-good artifact** (emergency; new tag must be higher than current):
```bash
flux list artifact oci://ghcr.io/<owner>/homelab/platform | grep -E '^\d+\.\d+\.\d+$'
.claude/skills/promotion-pipeline/scripts/manual-promote.sh <known-good-7char-sha> <higher-X.Y.Z>
```

**Option 3 — Pin OCIRepository** (immediate, must revert pin later):
```bash
kubectl --context live patch ocirepository flux-system -n flux-system \
  --type=merge -p '{"spec":{"ref":{"tag":"<previous-stable-tag>"}}}'
```

## Cross-References

| Document | Focus |
|----------|-------|
| `docs/architecture/promotion-pipeline.md` | Full pipeline architecture and design rationale |
| `.github/CLAUDE.md` | Workflow inventory |
| `kubernetes/clusters/CLAUDE.md` | Per-cluster source types |
| `kubernetes/platform/CLAUDE.md` | Flux patterns, version management |
| `flux-gitops` skill | Adding Helm releases and ResourceSet patterns |
