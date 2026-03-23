---
name: promotion-pipeline
description: |
  OCI artifact promotion pipeline from PR merge through integration validation to live deployment.

  Use when: (1) Tracing why a change has not reached a cluster, (2) Debugging artifacts stuck in integration,
  (3) Understanding the build/validate/promote lifecycle, (4) Performing manual promotion or rollback,
  (5) Investigating GitHub Actions workflow failures, (6) Checking OCI artifact tags in GHCR.

  Triggers: "promotion", "pipeline", "artifact", "oci", "integration deploy", "live deploy",
  "stuck in integration", "not deploying", "ghcr", "build artifact", "tag validated",
  "repository_dispatch", "canary-checker", "rollback", "semver", "image policy",
  "promotion pipeline", "why isn't live updating"
user-invocable: false
---

# Promotion Pipeline

The homelab uses an OCI artifact promotion pipeline for immutable, auditable deployments. Changes flow through three stages: build, validate in integration, promote to live. This skill covers end-to-end tracing and debugging.

## Pipeline Overview

```
PR merged to main (kubernetes/ changed)
       |
       v
build-platform-artifact.yaml (GHA)
  - Discovers latest stable tag in GHCR, bumps patch
  - Pushes OCI artifact with tag X.Y.Z-rc.N
  - Adds tags: sha-<short>, integration-<short>
       |
       v
Integration Cluster
  - OCIRepository polls GHCR with semver ">= 0.0.0-0" (includes RCs)
  - Detects new X.Y.Z-rc.N (higher than previous stable)
  - Flux reconciles platform Kustomization
       |
       v
Flux Alert (validation-success)
  - Watches platform Kustomization for "Reconciliation finished"
  - Fires repository_dispatch to GitHub (event_type: Kustomization/platform.flux-system)
  - Idempotency guard: workflow skips if artifact already has validated-<sha> tag
       |
       v
tag-validated-artifact.yaml (GHA)
  - Finds integration-<sha> artifact, extracts RC tag
  - Strips RC suffix: X.Y.Z-rc.N --> X.Y.Z
  - Tags artifact: validated-<sha> + X.Y.Z (stable semver)
       |
       v
Live Cluster
  - OCIRepository polls GHCR with semver ">= 0.0.0" (stable only)
  - Detects new X.Y.Z stable tag
  - Flux reconciles platform (production deployment)
```

See [references/pipeline-reference.md](references/pipeline-reference.md) for artifact tagging strategy, source types, failure modes, and key files.

## Tracing a Change End-to-End

Prefix cluster commands with `KUBECONFIG=~/.kube/<cluster>.yaml`. The build triggers on push to `main` when `kubernetes/**` files change only.

| Stage | Check | Command |
|-------|-------|---------|
| 1. GHA Build | Did build workflow trigger? | `gh run list --workflow=build-platform-artifact.yaml --limit=5` |
| 1. GHA Build | View logs | `gh run view <run-id> --log` |
| 2. GHCR | List/find artifacts | `flux list artifact oci://ghcr.io/<owner>/homelab/platform --limit=10 \| grep <short-sha>` |
| 3. Integration | OCIRepository status | `kubectl get ocirepository -n flux-system -o wide` |
| 3. Integration | Current deployed version | `kubectl get ocirepository flux-system -n flux-system -o jsonpath='{.status.artifact.revision}'` |
| 3. Integration | Kustomization status | `kubectl get kustomization platform -n flux-system` |
| 3. Integration | Force reconcile | `flux reconcile source oci flux-system -n flux-system` |
| 4. Alert | Status/events | `kubectl describe alert validation-success -n flux-system` |
| 4. Alert | Provider status | `kubectl get providers -n flux-system` |
| 5. Tag Workflow | Did tag workflow trigger? | `gh run list --workflow=tag-validated-artifact.yaml --limit=5` |
| 5. Tag Workflow | Manual trigger | `gh workflow run tag-validated-artifact.yaml -f artifact_sha=<7char-sha>` |
| 6. Live | OCIRepository status | `kubectl get ocirepository -n flux-system -o wide` |
| 6. Live | Current deployed version | `kubectl get ocirepository flux-system -n flux-system -o jsonpath='{.status.artifact.revision}'` |
| 6. Live | Kustomization status | `kubectl get kustomization platform -n flux-system` |

## Debugging: Artifact Stuck in Integration

```
Artifact in GHCR?
+-- NO  --> build workflow: did it trigger? GITHUB_TOKEN packages:write? "flux push artifact" errors?
+-- YES --> Integration OCIRepository seeing it?
    +-- NO  --> semver constraint ">= 0.0.0-0"? Check .status.conditions for errors
    +-- YES --> Kustomization reconciling?
        +-- NO  --> kubectl describe kustomization platform -n flux-system; dependency/schema errors?
        +-- YES --> Alert firing repository_dispatch?
            +-- NO  --> "validation-success" watches platform Kustomization?
                        "github-dispatch" provider has GitHub token (repo scope)?
            +-- YES --> tag workflow: idempotency guard (validated-<sha> already exists)? log errors?
```

## Debugging: Live Not Updating

```
Artifact tagged with stable X.Y.Z?
+-- NO  --> tag workflow ran? created both validated-<sha> and X.Y.Z tags?
+-- YES --> Live OCIRepository seeing stable tag?
    +-- NO  --> semver constraint ">= 0.0.0"? tag higher than current?
                flux reconcile source oci flux-system -n flux-system
    +-- YES --> Kustomization reconciling?
        +-- NO  --> Check status and dependencies
        +-- YES --> flux get helmreleases -A; health checks blocking rollout?
```

## Canary-Checker Validation

The `platform-validation` Canary in `monitoring` runs every 60s: `kubernetes-api` (HTTP, expects 200/401) and `flux-pods-healthy` (all Flux pods Running+Ready).

```bash
# Check canary status (prefix with KUBECONFIG=~/.kube/integration.yaml)
kubectl get canaries -n monitoring
kubectl describe canary platform-validation -n monitoring
# canary_check{name="platform-validation"} == 0 means healthy
```

Alerts: `CanaryCheckFailure` (critical, 2m) and `CanaryCheckHighFailureRate` (>20% over 15m, warning).

## Manual Promotion (Emergency)

```bash
# Preferred: workflow_dispatch
gh workflow run tag-validated-artifact.yaml -f artifact_sha=<7char-sha>

# If workflow is broken: GITHUB_TOKEN (packages:write + repo scope), GITHUB_USER, flux CLI required
.claude/skills/promotion-pipeline/scripts/manual-promote.sh <7char-sha> <X.Y.Z>
```

## Rollback Procedure

**Option 1 — Pin OCIRepository** (immediate, must revert pin later):
```bash
flux list artifact oci://ghcr.io/<owner>/homelab/platform | grep -E '^\d+\.\d+\.\d+$'
KUBECONFIG=~/.kube/live.yaml kubectl patch ocirepository flux-system -n flux-system \
  --type=merge -p '{"spec":{"ref":{"tag":"<previous-stable-tag>"}}}'
```

**Option 2 — Revert the PR** (safest): revert on main, pipeline re-runs naturally through integration to live.

**Option 3 — Re-tag a previous artifact** (new tag must be higher than current):
```bash
flux tag artifact oci://ghcr.io/<owner>/homelab/platform:validated-<old-sha> --tag <higher-X.Y.Z>
```

## Cross-References

| Document | Focus |
|----------|-------|
| `.github/CLAUDE.md` | Complete pipeline architecture and debugging guide |
| `kubernetes/clusters/CLAUDE.md` | Per-cluster source types and promotion path |
| `kubernetes/platform/CLAUDE.md` | Flux patterns, version management |
| `flux-gitops` skill | Adding Helm releases and ResourceSet patterns |
