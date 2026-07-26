# Promotion Pipeline Reference

## Artifact Tagging Strategy

Each artifact accumulates tags as it progresses through the pipeline:

| Tag | Created By | Stage | Purpose |
|-----|-----------|-------|---------|
| `X.Y.Z-rc.N` | build workflow | Build | Pre-release semver for integration polling |
| `sha-<7char>` | build workflow | Build | Immutable commit reference |
| `integration-<7char>` | build workflow | Build | Marks artifact for integration consumption |
| `validated-<7char>` | tag workflow | Promotion | Traceability for validated artifacts |
| `X.Y.Z` | tag workflow | Promotion | Stable semver for live polling |

**Version numbering**: The build workflow queries GHCR for the highest stable `X.Y.Z` tag, bumps patch to `X.Y.(Z+1)`, then creates `X.Y.(Z+1)-rc.N`. When validated, the RC suffix is stripped to produce `X.Y.(Z+1)`.

---

## Source Types by Cluster

| Cluster | Source Type | Semver Constraint | What It Accepts |
|---------|------------|-------------------|-----------------|
| dev | GitRepository | N/A | Git main branch directly |
| integration | OCIRepository | `>= 0.0.0-0` | All versions including pre-releases (`-rc.N`) |
| live | OCIRepository | `>= 0.0.0` | Stable versions only (no `-rc` suffix) |

The semver constraint is set in the config module (`infrastructure/modules/config/main.tf`) and applied via flux-operator bootstrap. The `-0` suffix in `>= 0.0.0-0` is what allows pre-release versions per semver specification.

---

## Common Failure Modes

| Symptom | Cause | Fix |
|---------|-------|-----|
| Build succeeds, integration does not update | OCIRepository semver does not match RC tags | Verify `>= 0.0.0-0` in OCIRepository spec |
| Validation passes, live does not update | Tag workflow did not create stable semver tag | Check tag-validated-artifact workflow logs |
| `repository_dispatch` not received by GHA | GitHub token in flux-system secret lacks `repo` scope | Update token with correct scopes |
| Tag workflow fires repeatedly (~10min) | Alert fires on every Flux reconciliation cycle | Normal -- idempotency guard skips already-validated artifacts |
| Artifact push fails in build workflow | GHCR auth issue | Check `GITHUB_TOKEN` has `packages:write` permission |
| Live picks up wrong version | Semver ordering issue with RC numbering | Verify stable tag is strictly higher than current |
| Integration shows "no matching artifact" | OCIRepository URL or semver misconfigured | Check `oci_url` and `oci_semver` in cluster bootstrap config |

---

## Key Files Reference

| File | Purpose |
|------|---------|
| `.github/workflows/build-platform-artifact.yaml` | Build and push OCI artifact on merge to main |
| `.github/workflows/tag-validated-artifact.yaml` | Promote validated artifact (tag stable semver) |
| `kubernetes/platform/config/flux-notifications/canary-alert.yaml` | Alert that triggers repository_dispatch |
| `kubernetes/platform/config/flux-notifications/github-provider.yaml` | GitHub dispatch provider for Flux alerts |
| `kubernetes/platform/config/canary-checker/platform-health.yaml` | Platform health validation checks |
| `infrastructure/modules/config/main.tf` | OCI semver constraints per cluster |
| `infrastructure/modules/bootstrap/resources/instance-oci.yaml.tftpl` | OCIRepository bootstrap template |
