# Promotion Pipeline Reference

## Artifact Tagging Strategy

All tags are applied at build time by `build-platform-artifact.yaml` — there is no later promotion step that adds tags:

| Tag | Created By | Purpose |
|-----|-----------|---------|
| `X.Y.Z` | build workflow | Stable semver for cluster OCIRepository polling |
| `sha-<7char>` | build workflow | Immutable commit reference for audit trail |
| `validated-<7char>` | build workflow | Compatibility tag for live cluster's `tag_pattern` filter |

**Version numbering**: The build workflow queries GHCR for the highest stable `X.Y.Z` tag and bumps patch to `X.Y.(Z+1)`. No RC suffix is used. A GitHub Release `vX.Y.Z` is created for each build.

---

## Source Types by Cluster

| Cluster | Source Type | Semver Constraint | What It Accepts |
|---------|------------|-------------------|-----------------|
| dev | GitRepository | N/A | Git main branch directly |
| integration | OCIRepository | `>= 0.0.0-0` | All versions including pre-releases (none are built today) |
| live | OCIRepository | `>= 0.0.0` | Stable versions only |

The semver constraint is set in the config module (`infrastructure/modules/config/main.tf`) and applied via flux-operator bootstrap. Integration's `-0` suffix is a holdover from the old RC-based flow; since only stable tags are built, integration and live receive the same artifacts. Integration is **not** a validation gate.

---

## Common Failure Modes

| Symptom | Cause | Fix |
|---------|-------|-----|
| Merge succeeds, live does not update | Build workflow did not trigger | Verify `kubernetes/**` was in the changed paths |
| Artifact push fails in build workflow | GHCR auth issue | Check `GITHUB_TOKEN` has `packages:write` permission |
| Artifact built but no GitHub Release | Release step failed | Check workflow logs; verify `contents: write` permission |
| Artifact in GHCR, live OCIRepository not updating | Semver constraint or tag ordering | Verify `>= 0.0.0` and that the new tag is strictly higher than current |
| Live shows "no matching artifact" | OCIRepository URL or semver misconfigured | Check `oci_url` and `oci_semver` in cluster bootstrap config |
| Deploy succeeded but canary alert firing | Broken config reached live | Investigate canary check details; consider revert |

---

## Key Files Reference

| File | Purpose |
|------|---------|
| `.github/workflows/build-platform-artifact.yaml` | Build, tag (stable/sha/validated), push OCI artifact, create GitHub Release |
| `kubernetes/platform/config/canary-checker/platform-health.yaml` | Post-deploy platform health validation checks |
| `kubernetes/platform/config/canary-checker/prometheus-rules.yaml` | CanaryCheckFailure alerting rules |
| `infrastructure/modules/config/main.tf` | OCI semver constraints per cluster |
| `infrastructure/modules/bootstrap/resources/instance-oci.yaml.tftpl` | OCIRepository bootstrap template |
| `docs/architecture/promotion-pipeline.md` | Full architecture and design rationale |
