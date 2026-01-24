# Renovate/Flux Environment Promotion Strategy

## Overview

Implement an **event-driven** staged promotion pipeline where:
1. **Renovate** updates versions on **dev** (bleeding edge, auto-merged PRs)
2. **Flux notifications** report reconciliation status to GitHub (commit status)
3. **Automated promotion to integration** - all successful dev components immediately promote via auto-merged PR
4. **Selective promotion to live** - components promote based on soak period and approval policy
5. **Partial promotion** supported - successful components promote even if others fail

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
                        Dev                Integration              Live
                       Cluster               Cluster               Cluster
                          │                     │                     │
Renovate PR ──────────────▶                     │                     │
  (auto-merge)            │                     │                     │
                          │                     │                     │
                   Flux reconciles              │                     │
                          │                     │                     │
GitHub ◀──commit status───┤                     │                     │
           (per component)│                     │                     │
                          │                     │                     │
         [IMMEDIATE]      │                     │                     │
                          │                     │                     │
GH Action: promote ───────┼─── auto-merged PR ──▶                     │
  to integration          │    (all components) │                     │
  (auto-merge)            │                     │                     │
                          │              Flux reconciles              │
                          │                     │                     │
GitHub ◀──commit status───┼─────────────────────┤                     │
           (per component)│                     │                     │
                          │                     │                     │
         [1-HOUR SOAK + SELECTIVE]              │                     │
                          │                     │                     │
GH Action: promote ───────┼─────────────────────┼─── auto-merged PR ──▶
  to live (selective)     │                     │    (approved only)  │
                          │                     │                     │
                          │                     │           Flux reconciles
```

**Promotion Model:**
- **dev → integration**: Automatic, immediate, ALL components (k8s + talos)
- **integration → live**: Selective, soak period required, approval-based

### Key Design Decisions

1. **Stack-level versions**: Remove centralized `versions.hcl`, versions defined per-stack
2. **Dev-first updates**: Renovate updates dev only, integration/live receive promotions
3. **Auto-merged PRs**: All promotions use PRs with auto-merge (like Renovate PRs), maintaining branch protection
4. **Two-stage promotion**:
   - **dev → integration**: Automatic, immediate, ALL components (k8s + talos) - "send it"
   - **integration → live**: Selective, 1-hour soak period, approval-based
5. **Partial promotion**: If 8/10 HelmReleases succeed, promote those 8

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

Update Renovate to target **dev only** with auto-merge. Integration and live receive versions via promotion workflows.

**Modify** `.github/renovate.json5`:
```json5
{
  "packageRules": [
    {
      // Infrastructure versions - dev only (bleeding edge)
      "matchFileNames": [
        "infrastructure/stacks/dev/terragrunt.stack.hcl"
      ],
      "groupName": "infrastructure-versions-dev",
      "labels": ["dependencies", "infrastructure", "bleeding-edge"],
      "automerge": true
    },
    {
      // Helm chart updates - dev only (bleeding edge)
      "matchManagers": ["kubernetes"],
      "matchFileNames": [
        "kubernetes/clusters/dev/helm-charts.yaml"
      ],
      "groupName": "helm-charts-dev",
      "labels": ["dependencies", "kubernetes", "bleeding-edge"],
      "automerge": true
    },
    {
      // Block direct Renovate updates to integration + live
      // These receive versions via promotion workflows only
      "matchFileNames": [
        "infrastructure/stacks/integration/terragrunt.stack.hcl",
        "infrastructure/stacks/live/terragrunt.stack.hcl",
        "kubernetes/clusters/integration/helm-charts.yaml",
        "kubernetes/clusters/live/helm-charts.yaml"
      ],
      "enabled": false
    }
  ],

  "customManagers": [
    {
      // Talos version in stack files
      "customType": "regex",
      "fileMatch": ["infrastructure/stacks/dev/terragrunt\\.stack\\.hcl$"],
      "matchStrings": [
        "talos\\s*=\\s*\"(?<currentValue>v[0-9]+\\.[0-9]+\\.[0-9]+)\""
      ],
      "depNameTemplate": "siderolabs/talos",
      "datasourceTemplate": "github-releases"
    },
    {
      // Kubernetes version in stack files
      "customType": "regex",
      "fileMatch": ["infrastructure/stacks/dev/terragrunt\\.stack\\.hcl$"],
      "matchStrings": [
        "kubernetes\\s*=\\s*\"(?<currentValue>[0-9]+\\.[0-9]+\\.[0-9]+)\""
      ],
      "depNameTemplate": "kubernetes/kubernetes",
      "datasourceTemplate": "github-releases",
      "extractVersionTemplate": "^v(?<version>.*)$"
    },
    {
      // Cilium version in stack files
      "customType": "regex",
      "fileMatch": ["infrastructure/stacks/dev/terragrunt\\.stack\\.hcl$"],
      "matchStrings": [
        "cilium\\s*=\\s*\"(?<currentValue>[0-9]+\\.[0-9]+\\.[0-9]+)\""
      ],
      "depNameTemplate": "cilium",
      "datasourceTemplate": "helm",
      "registryUrlTemplate": "https://helm.cilium.io"
    },
    {
      // Flux version in stack files
      "customType": "regex",
      "fileMatch": ["infrastructure/stacks/dev/terragrunt\\.stack\\.hcl$"],
      "matchStrings": [
        "flux\\s*=\\s*\"(?<currentValue>v[0-9]+\\.[0-9]+\\.[0-9]+)\""
      ],
      "depNameTemplate": "fluxcd/flux2",
      "datasourceTemplate": "github-releases"
    }
  ]
}
```

### Phase 5: Event-Driven Promotion Automation

Create GitHub Actions workflows for two-stage promotion using auto-merged PRs.

#### 5a. Promote to Integration (Automatic - "Send It")

**File to create:** `.github/workflows/promote-to-integration.yaml`

```yaml
name: Promote to Integration

on:
  # Triggered when commit status changes (Flux notifications from dev)
  status:
  workflow_dispatch:
    inputs:
      component:
        description: 'Specific component to promote (leave empty for all eligible)'
        type: string

jobs:
  promote-to-integration:
    # Only run for dev cluster Flux status updates
    if: |
      github.event.state == 'success' &&
      contains(github.event.context, 'flux') &&
      contains(github.event.context, 'dev')
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write
    steps:
      - uses: actions/checkout@v4

      - name: Parse Flux status
        id: status
        run: |
          COMPONENT=$(echo '${{ github.event.context }}' | sed 's/.*\///')
          echo "component=${COMPONENT}" >> $GITHUB_OUTPUT

      - name: Check promotion eligibility
        id: check
        run: |
          set -euo pipefail

          # Compare dev vs integration versions
          HELM_DIFF=$(diff -q kubernetes/clusters/dev/helm-charts.yaml \
                          kubernetes/clusters/integration/helm-charts.yaml 2>/dev/null || true)

          # Extract versions from HCL files using grep (yq doesn't parse HCL)
          DEV_VERSIONS=$(grep -A20 'versions = {' infrastructure/stacks/dev/terragrunt.stack.hcl | head -20)
          INT_VERSIONS=$(grep -A20 'versions = {' infrastructure/stacks/integration/terragrunt.stack.hcl | head -20)

          COMPONENTS=""
          if [ -n "${HELM_DIFF}" ]; then
            COMPONENTS="helm-charts"
          fi

          if [ "${DEV_VERSIONS}" != "${INT_VERSIONS}" ]; then
            COMPONENTS="${COMPONENTS:+$COMPONENTS, }infrastructure-versions"
          fi

          if [ -z "${COMPONENTS}" ]; then
            echo "No version differences found between dev and integration"
            echo "promotable=false" >> $GITHUB_OUTPUT
            exit 0
          fi

          echo "Components to promote: ${COMPONENTS}"
          echo "promotable=true" >> $GITHUB_OUTPUT
          echo "components=${COMPONENTS}" >> $GITHUB_OUTPUT

      - name: Create promotion branch
        if: steps.check.outputs.promotable == 'true'
        id: branch
        run: |
          BRANCH="promote/integration-$(date +%Y%m%d-%H%M%S)"
          git checkout -b "${BRANCH}"
          echo "branch=${BRANCH}" >> $GITHUB_OUTPUT

      - name: Promote ALL versions (Helm + Infra)
        if: steps.check.outputs.promotable == 'true'
        run: |
          set -euo pipefail

          # Copy Helm chart versions: dev → integration
          if [ -f kubernetes/clusters/dev/helm-charts.yaml ]; then
            cp kubernetes/clusters/dev/helm-charts.yaml \
               kubernetes/clusters/integration/helm-charts.yaml
            echo "Promoted Helm chart versions"
          fi

          # Copy infrastructure versions: dev → integration
          # Use sed to extract and replace versions block (HCL-aware)
          if [ -f infrastructure/stacks/dev/terragrunt.stack.hcl ]; then
            # Extract versions block from dev
            sed -n '/versions = {/,/^  }/p' infrastructure/stacks/dev/terragrunt.stack.hcl > /tmp/versions-block.txt

            # Replace in integration (using markers)
            sed -i '/versions = {/,/^  }/{
              /versions = {/r /tmp/versions-block.txt
              d
            }' infrastructure/stacks/integration/terragrunt.stack.hcl
            echo "Promoted infrastructure versions"
          fi

      - name: Create auto-merge PR
        if: steps.check.outputs.promotable == 'true'
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          set -euo pipefail

          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"

          git add kubernetes/clusters/integration/ infrastructure/stacks/integration/
          git diff --staged --quiet && { echo "No changes to commit"; exit 0; }

          git commit -m "chore(infra): promote to integration

          Automated promotion of all components from dev.
          Triggered by successful Flux reconciliation.

          Components: ${{ steps.check.outputs.components }}"

          # Push with retry for race conditions
          for i in 1 2 3; do
            git push -u origin "${{ steps.branch.outputs.branch }}" && break
            echo "Push attempt $i failed, retrying..."
            sleep 5
          done

          # Create PR
          PR_URL=$(gh pr create \
            --title "chore(infra): promote to integration" \
            --body "## Automated Promotion

          Promotes all successful dev components to integration.

          **Trigger:** Flux reconciliation success on dev cluster
          **Components:** ${{ steps.check.outputs.components }}

          This PR will auto-merge after CI passes." \
            --label "promotion,auto-merge" 2>&1) || {
              echo "PR creation failed: ${PR_URL}"
              exit 1
            }

          echo "Created PR: ${PR_URL}"

          # Enable auto-merge (may fail if not enabled on repo, that's OK)
          gh pr merge --auto --squash || echo "Auto-merge not available, PR requires manual merge"
```

#### 5b. Promote to Live (Selective - Approval Required)

**File to create:** `.github/workflows/promote-to-live.yaml`

```yaml
name: Promote to Live

on:
  # Triggered when commit status changes (Flux notifications from integration)
  status:
  # Manual trigger for selective promotion
  workflow_dispatch:
    inputs:
      component:
        description: 'Specific component to promote'
        type: string
        required: true
      skip_soak:
        description: 'Skip soak period check (emergency only)'
        type: boolean
        default: false

jobs:
  check-soak-period:
    # Only run for integration cluster Flux status updates
    if: |
      github.event.state == 'success' &&
      contains(github.event.context, 'flux') &&
      contains(github.event.context, 'integration')
    runs-on: ubuntu-latest
    outputs:
      eligible: ${{ steps.soak.outputs.eligible }}
      components: ${{ steps.soak.outputs.components }}
    steps:
      - uses: actions/checkout@v4

      - name: Check soak period
        id: soak
        run: |
          # Query git log for when integration was last updated
          # Components must have been stable for 1 hour minimum
          LAST_INTEGRATION_UPDATE=$(git log -1 --format=%ct -- kubernetes/clusters/integration/ infrastructure/stacks/integration/)
          NOW=$(date +%s)
          SOAK_SECONDS=$((NOW - LAST_INTEGRATION_UPDATE))
          SOAK_HOURS=$((SOAK_SECONDS / 3600))

          if [ "${SOAK_HOURS}" -lt 1 ]; then
            echo "Soak period not met: ${SOAK_HOURS}h < 1h required"
            echo "eligible=false" >> $GITHUB_OUTPUT
          else
            echo "Soak period satisfied: ${SOAK_HOURS}h"
            echo "eligible=true" >> $GITHUB_OUTPUT
          fi

  promote-to-live:
    needs: check-soak-period
    if: needs.check-soak-period.outputs.eligible == 'true'
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write
    steps:
      - uses: actions/checkout@v4

      - name: Check promotion eligibility
        id: check
        run: |
          # Compare integration vs live versions
          # Identify components that differ and are eligible for promotion
          # For selective promotion: only promote stable components

      - name: Create promotion branch
        run: |
          BRANCH="promote/live-$(date +%Y%m%d-%H%M%S)"
          git checkout -b "${BRANCH}"
          echo "branch=${BRANCH}" >> $GITHUB_OUTPUT

      - name: Promote versions (selective)
        run: |
          # Copy Helm chart versions: integration → live
          cp kubernetes/clusters/integration/helm-charts.yaml \
             kubernetes/clusters/live/helm-charts.yaml

          # Copy infrastructure versions: integration → live
          yq eval '.locals.versions' infrastructure/stacks/integration/terragrunt.stack.hcl \
            | yq eval -i '.locals.versions = load("/dev/stdin")' \
              infrastructure/stacks/live/terragrunt.stack.hcl

      - name: Create PR (requires approval)
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          git add kubernetes/clusters/live/ infrastructure/stacks/live/
          git diff --staged --quiet && exit 0  # Nothing to promote

          git commit -m "chore(infra): promote to live

          Automated promotion from integration after soak period.

          Components: ${{ steps.check.outputs.components }}"

          git push -u origin "${BRANCH}"

          gh pr create \
            --title "chore(infra): promote to live" \
            --body "## Production Promotion

          Promotes components from integration to live after 1-hour soak.

          **Soak period:** Satisfied
          **Components:** ${{ steps.check.outputs.components }}

          ⚠️ **Requires approval before merge**" \
            --label "promotion,production"

          # Enable auto-merge (will wait for required approvals)
          gh pr merge --auto --squash
```

---

## Files Summary

| File | Action | Purpose |
|------|--------|---------|
| **Infrastructure Stacks** | | |
| `infrastructure/stacks/dev/terragrunt.stack.hcl` | MODIFY | Add versions block (Renovate target) |
| `infrastructure/stacks/integration/terragrunt.stack.hcl` | MODIFY | Add versions block (promotion target) |
| `infrastructure/stacks/live/terragrunt.stack.hcl` | MODIFY | Add versions block (promotion target) |
| `infrastructure/versions.hcl` | DELETE | Remove centralized versions |
| `infrastructure/units/config/terragrunt.hcl` | MODIFY | Accept versions input |
| `infrastructure/units/talos/terragrunt.hcl` | MODIFY | Accept versions input |
| `infrastructure/units/bootstrap/terragrunt.hcl` | MODIFY | Accept versions input |
| **Kubernetes Clusters** | | |
| `kubernetes/clusters/dev/helm-charts.yaml` | CREATE | Per-cluster Helm versions (Renovate target) |
| `kubernetes/clusters/integration/helm-charts.yaml` | CREATE | Per-cluster Helm versions (promotion target) |
| `kubernetes/clusters/live/helm-charts.yaml` | CREATE | Per-cluster Helm versions (promotion target) |
| `kubernetes/clusters/*/kustomization.yaml` | MODIFY | Reference helm-charts.yaml |
| `kubernetes/platform/kustomization.yaml` | MODIFY | Remove helm-charts reference |
| **Flux Notifications** | | |
| `kubernetes/platform/config/flux-notifications/` | CREATE | Notification resources |
| **Renovate & Automation** | | |
| `.github/renovate.json5` | MODIFY | Target dev only with auto-merge |
| `.github/workflows/promote-to-integration.yaml` | CREATE | Auto-merge PR promotion (dev → integration) |
| `.github/workflows/promote-to-live.yaml` | CREATE | Selective PR promotion (integration → live) |

---

## Verification

1. **Stack validation**: Run `task tg:validate-dev`, `task tg:validate-integration`, `task tg:validate-live`
2. **Renovate targeting**: Create test branch, verify Renovate proposes updates to dev only (not integration/live)
3. **Auto-merge config**: Verify Renovate PRs to dev have auto-merge enabled and merge after CI passes
4. **Flux notifications**: Deploy notification resources, verify GitHub commit status appears for each cluster
5. **Dev → Integration promotion**:
   - Merge a Renovate PR to dev
   - Verify GH Action creates auto-merge PR for integration
   - Verify PR merges automatically after CI passes
   - Verify integration cluster reconciles with new versions
6. **Integration → Live promotion**:
   - Wait 1-hour soak period after integration update
   - Verify GH Action creates PR for live (requires approval)
   - Approve and merge PR
   - Verify live cluster reconciles with new versions
7. **Partial promotion**: Intentionally fail one HelmRelease, verify only successful ones promote
8. **End-to-end flow**: Renovate PR → dev reconcile → auto-merge to integration → soak → approved merge to live

---

## Rollback Strategy

Since all state is in git:
1. **Revert promotion commit**: `git revert <sha>` on the promotion commit
2. **Flux auto-reconciles**: Live cluster returns to previous versions
3. **Investigate on integration**: Debug the failing component before re-promoting

For infrastructure versions that affect Talos/K8s:
1. Revert the stack's versions block changes
2. Re-run Terragrunt to regenerate machine configs if needed
