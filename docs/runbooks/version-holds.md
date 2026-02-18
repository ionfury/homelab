# Runbook: Version Holds

## Overview

How to hold back a dependency version when an upstream release has a regression, and how the automated monitoring works. This prevents Renovate from auto-merging a broken version back after a manual downgrade.

## Prerequisites

- Write access to the repository
- Understanding of Renovate package rules and `allowedVersions` syntax
- Familiarity with `kubernetes/platform/versions.env` version management

## When to Use

- An upstream release introduces a regression that affects the homelab
- Renovate would auto-merge the broken version back after a downgrade
- The upstream project has a tracking issue for the regression

## Procedure

### Step 1: Downgrade the version

Edit `kubernetes/platform/versions.env` and set the version to the last known good release:

```env
# renovate: datasource=docker depName=gluetun packageName=ghcr.io/qdm12/gluetun
gluetun_version=v3.40.0
```

### Step 2: Add the hold entry

Add an entry to `.github/version-holds.yaml`:

```yaml
holds:
  - dep: gluetun                          # Dependency name (matches depName in versions.env)
    constraint: "!/^v3\\.41\\./"          # Renovate allowedVersions regex to block bad versions
    reason: "v3.41.x healthcheck regression blocks DNS queries"  # Human-readable explanation
    upstream_issue: https://github.com/qdm12/gluetun/issues/3132  # GitHub issue tracking the fix
    created: "2026-02-18"                 # Date the hold was created (ISO 8601)
```

**Field reference:**

| Field | Required | Description |
|-------|----------|-------------|
| `dep` | Yes | Dependency name matching the Renovate `depName` |
| `constraint` | Yes | Renovate `allowedVersions` pattern (regex or range) |
| `reason` | Yes | Why this version is held back |
| `upstream_issue` | Yes | GitHub issue URL tracking the upstream fix |
| `created` | Yes | ISO 8601 date when the hold was created |

### Step 3: Add Renovate constraint

Add a package rule to `.github/renovate.json5` in the `packageRules` array, under the "Version holds" section:

```json5
// ============================================================
// Version holds — upstream regressions (see .github/version-holds.yaml)
// ============================================================
{
  // gluetun v3.41.x: healthcheck regression blocks DNS to kube-dns
  // Upstream: https://github.com/qdm12/gluetun/issues/3132
  "matchDepNames": ["gluetun"],
  "allowedVersions": "!/^v3\\.41\\./"
}
```

The `allowedVersions` value must match the `constraint` field in `version-holds.yaml`.

### Step 4: Validate and merge

```bash
task k8s:validate
task renovate:validate
```

Commit, push, and create a PR. After merge, Renovate will respect the constraint and not propose the blocked version.

## Automated Monitoring

The `check-version-holds.yaml` workflow runs weekly (Monday 8am ET) and checks each upstream issue via the GitHub API. When an upstream issue is closed:

1. The workflow creates a GitHub issue in this repository with the `version-hold` label
2. The issue contains the dependency details, constraint, and step-by-step removal instructions
3. Duplicate issues are prevented via title-based idempotency checks

The workflow also runs on push to `main` when `.github/version-holds.yaml` changes, serving as a validation that the file is well-formed.

## Removing a Hold

When notified (via GitHub issue) that an upstream issue has closed:

1. Verify the fix is actually released in a new version
2. Remove the entry from `.github/version-holds.yaml`
3. Remove the corresponding `allowedVersions` package rule from `.github/renovate.json5`
4. Run `task k8s:validate` and `task renovate:validate`
5. Commit and create a PR
6. After merge, Renovate will propose updating to the latest version
7. Verify the new version works in dev/integration before it reaches live
8. Close the tracking issue

## Verification

- Check the [Actions tab](../../actions/workflows/check-version-holds.yaml) for workflow run history
- Check [open issues with `version-hold` label](../../issues?q=is%3Aissue+is%3Aopen+label%3Aversion-hold) for pending removals
- Run the workflow manually via `workflow_dispatch` to test

## Related

- `.github/version-holds.yaml` -- declarative holds registry
- `.github/renovate.json5` -- Renovate package rules with `allowedVersions` constraints
- `.github/workflows/check-version-holds.yaml` -- automated upstream issue monitoring
- `kubernetes/platform/versions.env` -- version source of truth
