# Renovate/Flux Environment Promotion Strategy

## Overview

Implement an **event-driven** staged promotion pipeline where:
1. **Renovate** updates versions on **dev + integration** together (same PR, bleeding edge)
2. **Flux notifications** report reconciliation status to GitHub (commit status)
3. **Automated promotion** immediately promotes to **live** when integration reports success
4. **Partial promotion** supported - successful components promote even if others fail

---

## Architecture Design

### Current State

- `infrastructure/versions.hcl` - Centralized version file (to be removed)
- `kubernetes/platform/helm-charts.yaml` - Shared ResourceSet with hard-coded versions
- No Flux notification infrastructure exists
- Integration/live cluster directories don't exist yet (bootstrap pending)

### Proposed Architecture

**Key Change: Stack-level versions** - Each cluster (dev, integration, live) maintains its own versions.

```
infrastructure/stacks/
├── dev/terragrunt.stack.hcl         # versions block (Renovate: bleeding edge)
├── integration/terragrunt.stack.hcl # versions block (Renovate: bleeding edge)
└── live/terragrunt.stack.hcl        # versions block (promotion target)

kubernetes/clusters/
├── dev/helm-charts.yaml             # Helm versions (Renovate: bleeding edge)
├── integration/helm-charts.yaml     # Helm versions (Renovate: bleeding edge)
└── live/helm-charts.yaml            # Helm versions (promotion target)
```

### Flow Diagram

```
Renovate PR                  Dev & Integration              Live
     │                          Clusters                   Cluster
     │                             │                          │
     ├──update dev/ + ─────────────▶                          │
     │   integration/              │                          │
     │   (same PR)                 │                          │
     │                             │                          │
     │                    Flux reconciles                     │
     │                    (both clusters)                     │
     │                             │                          │
     │◀───commit status────────────┤                          │
     │    (success/fail per chart) │                          │
     │                             │                          │
     │   [IMMEDIATE - no soak]     │                          │
     │                             │                          │
     ├──GH Action triggered────────┤                          │
     │   by integration status     │                          │
     │                             │                          │
     │   [promote successful       │                          │
     │    components only]         │                          │
     │                             │                          │
     ├──commit: copy versions──────────────────────────────────▶
     │   from integration → live                              │
     │                                                        │
     │                                               Flux reconciles
```

### Key Design Decisions

1. **Stack-level versions**: Remove centralized `versions.hcl`, versions defined per-stack
2. **Dev + Integration together**: Renovate updates both in same PR (bleeding edge)
3. **Event-driven promotion**: Flux success on integration = immediate promotion to live
4. **Partial promotion**: If 8/10 HelmReleases succeed, promote those 8
5. **Direct commit (no PR)**: Promotions commit directly to main for speed

---

## Implementation Plan

### Phase 1: Stack-Level Infrastructure Versions

Move versions from centralized file to each stack's `terragrunt.stack.hcl`.

#### 1a. Update Stack Files

**Modify** `infrastructure/stacks/dev/terragrunt.stack.hcl`:
```hcl
locals {
  name                 = "dev"
  features             = ["gateway-api", "longhorn", "prometheus", "spegel"]
  storage_provisioning = "minimal"

  # Infrastructure versions (Renovate updates this)
  versions = {
    talos       = "v1.12.1"
    kubernetes  = "1.35.0"
    cilium      = "1.18.6"
    gateway_api = "v1.4.1"
    flux        = "v2.7.5"
    prometheus  = "20.0.0"
  }
}

unit "config" {
  source = "../../units/config"
  path   = "config"

  values = {
    name                 = local.name
    features             = local.features
    storage_provisioning = local.storage_provisioning
    versions             = local.versions  # Pass versions to units
  }
}
# ... rest of units
```

**Apply same pattern to:**
- `infrastructure/stacks/integration/terragrunt.stack.hcl`
- `infrastructure/stacks/live/terragrunt.stack.hcl`

#### 1b. Update Units to Accept Versions

**Modify** units to receive versions as input instead of reading from `versions.hcl`:
- `infrastructure/units/config/terragrunt.hcl` - Accept `versions` input
- `infrastructure/units/talos/terragrunt.hcl` - Accept `versions` input
- `infrastructure/units/bootstrap/terragrunt.hcl` - Accept `versions` input

#### 1c. Remove Centralized Versions File

**Delete** `infrastructure/versions.hcl` after all stacks are updated.

### Phase 2: Per-Cluster Helm Charts

Create cluster-specific `helm-charts.yaml` files.

**Files to create:**
- `kubernetes/clusters/dev/helm-charts.yaml` - Copy of current helm-charts.yaml
- `kubernetes/clusters/integration/helm-charts.yaml` - Copy of current helm-charts.yaml
- `kubernetes/clusters/live/helm-charts.yaml` - Copy of current helm-charts.yaml

**Files to modify:**
- `kubernetes/clusters/dev/kustomization.yaml` - Add helm-charts.yaml to resources
- `kubernetes/clusters/integration/kustomization.yaml` - Add helm-charts.yaml to resources
- `kubernetes/clusters/live/kustomization.yaml` - Add helm-charts.yaml to resources
- `kubernetes/platform/kustomization.yaml` - Remove helm-charts.yaml reference

### Phase 3: Flux Notification Infrastructure

Create Flux notification resources to report reconciliation status to GitHub.

**Files to create:**
```
kubernetes/platform/config/flux-notifications/
├── kustomization.yaml
├── github-provider.yaml      # Provider for GitHub commit status
└── reconciliation-alert.yaml # Alert for Kustomization/HelmRelease events
```

**GitHub Provider** (`github-provider.yaml`):
```yaml
apiVersion: notification.toolkit.fluxcd.io/v1beta3
kind: Provider
metadata:
  name: github-status
  namespace: flux-system
spec:
  type: github
  address: https://github.com/<owner>/homelab
  secretRef:
    name: flux-system  # Reuse existing GitHub token
```

**Reconciliation Alert** (`reconciliation-alert.yaml`):
```yaml
apiVersion: notification.toolkit.fluxcd.io/v1beta3
kind: Alert
metadata:
  name: github-commit-status
  namespace: flux-system
spec:
  providerRef:
    name: github-status
  eventSeverity: info
  eventSources:
    - kind: Kustomization
      name: '*'
    - kind: HelmRelease
      name: '*'
```

### Phase 4: Renovate Configuration

Update Renovate to target dev + integration together, exclude live.

**Modify** `.github/renovate.json5`:
```json5
{
  "packageRules": [
    {
      // Infrastructure versions - dev + integration together
      "matchFileNames": [
        "infrastructure/stacks/dev/terragrunt.stack.hcl",
        "infrastructure/stacks/integration/terragrunt.stack.hcl"
      ],
      "groupName": "infrastructure-versions",
      "labels": ["dependencies", "infrastructure", "bleeding-edge"]
    },
    {
      // Helm chart updates - dev + integration together
      "matchManagers": ["kubernetes"],
      "matchFileNames": [
        "kubernetes/clusters/dev/helm-charts.yaml",
        "kubernetes/clusters/integration/helm-charts.yaml"
      ],
      "groupName": "helm-charts",
      "labels": ["dependencies", "kubernetes", "bleeding-edge"]
    },
    {
      // Block direct updates to live cluster
      "matchFileNames": [
        "infrastructure/stacks/live/terragrunt.stack.hcl",
        "kubernetes/clusters/live/helm-charts.yaml"
      ],
      "enabled": false
    }
  ],

  // Remove old custom managers for versions.hcl (will be replaced)
  // Update custom managers to target stack files instead
}
```

**Update custom managers** to match `terragrunt.stack.hcl` files instead of `versions.hcl`.

### Phase 5: Event-Driven Promotion Automation

Create GitHub Actions workflow triggered by Flux notification.

**File to create:** `.github/workflows/promote-to-live.yaml`

```yaml
name: Promote to Live

on:
  # Triggered when commit status changes (Flux notifications)
  status:
  workflow_dispatch:
    inputs:
      force:
        description: 'Force promotion even if some components failed'
        type: boolean
        default: false

jobs:
  check-and-promote:
    # Only run for integration cluster Flux status updates
    if: |
      github.event.state == 'success' &&
      contains(github.event.context, 'flux') &&
      contains(github.event.context, 'integration')
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Parse Flux status
        id: status
        run: |
          echo "component=$(echo '${{ github.event.context }}' | sed 's/.*\///')" >> $GITHUB_OUTPUT
          echo "success=${{ github.event.state == 'success' }}" >> $GITHUB_OUTPUT

      - name: Check promotion eligibility
        id: check
        run: |
          # Compare integration vs live versions
          # For Helm: diff helm-charts.yaml files
          # For infra: diff terragrunt.stack.hcl version blocks
          # Output list of promotable components

      - name: Promote Helm chart versions
        if: steps.check.outputs.helm_promotable != ''
        run: |
          # Copy updated chart entries from integration → live
          cp kubernetes/clusters/integration/helm-charts.yaml \
             kubernetes/clusters/live/helm-charts.yaml

      - name: Promote infrastructure versions
        if: steps.check.outputs.infra_promotable != ''
        run: |
          # Extract versions block from integration stack
          # Update live stack's versions block

      - name: Commit promotion
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add kubernetes/clusters/live/ infrastructure/stacks/live/
          git diff --staged --quiet || git commit -m "chore(k8s): promote to live

          Automated promotion triggered by successful Flux reconciliation on integration.

          Components: ${{ steps.check.outputs.components }}"
          git push
```

---

## Files Summary

| File | Action | Purpose |
|------|--------|---------|
| **Infrastructure Stacks** | | |
| `infrastructure/stacks/dev/terragrunt.stack.hcl` | MODIFY | Add versions block |
| `infrastructure/stacks/integration/terragrunt.stack.hcl` | MODIFY | Add versions block |
| `infrastructure/stacks/live/terragrunt.stack.hcl` | MODIFY | Add versions block |
| `infrastructure/versions.hcl` | DELETE | Remove centralized versions |
| `infrastructure/units/config/terragrunt.hcl` | MODIFY | Accept versions input |
| `infrastructure/units/talos/terragrunt.hcl` | MODIFY | Accept versions input |
| `infrastructure/units/bootstrap/terragrunt.hcl` | MODIFY | Accept versions input |
| **Kubernetes Clusters** | | |
| `kubernetes/clusters/dev/helm-charts.yaml` | CREATE | Per-cluster Helm versions |
| `kubernetes/clusters/integration/helm-charts.yaml` | CREATE | Per-cluster Helm versions |
| `kubernetes/clusters/live/helm-charts.yaml` | CREATE | Per-cluster Helm versions |
| `kubernetes/clusters/*/kustomization.yaml` | MODIFY | Reference helm-charts.yaml |
| `kubernetes/platform/kustomization.yaml` | MODIFY | Remove helm-charts reference |
| **Flux Notifications** | | |
| `kubernetes/platform/config/flux-notifications/` | CREATE | Notification resources |
| **Renovate & Automation** | | |
| `.github/renovate.json5` | MODIFY | Target dev + integration |
| `.github/workflows/promote-to-live.yaml` | CREATE | Event-driven promotion |

---

## Verification

1. **Stack validation**: Run `task tg:validate-dev`, `task tg:validate-integration`, `task tg:validate-live`
2. **Renovate targeting**: Create test branch, verify Renovate proposes updates to dev + integration (same PR)
3. **Flux notifications**: Deploy notification resources, verify GitHub commit status appears
4. **Promotion trigger**: Merge a version change, verify GH Action triggers on integration Flux success
5. **Partial promotion**: Intentionally fail one HelmRelease, verify only successful ones promote
6. **End-to-end**: Merge Renovate PR → dev + integration reconcile → promotion commits → live reconciles

---

## Rollback Strategy

Since all state is in git:
1. **Revert promotion commit**: `git revert <sha>` on the promotion commit
2. **Flux auto-reconciles**: Live cluster returns to previous versions
3. **Investigate on integration**: Debug the failing component before re-promoting

For infrastructure versions that affect Talos/K8s:
1. Revert the stack's versions block changes
2. Re-run Terragrunt to regenerate machine configs if needed
