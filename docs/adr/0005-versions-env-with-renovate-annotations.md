# Versions live in versions.env files with inline Renovate annotations

Every chart, image and platform version is a variable in `kubernetes/platform/versions.env` or a cluster's `versions.env`, annotated inline for Renovate and substituted by Flux; manifests reference `${variables}` rather than literal versions. This gives one place to change a version and one update path (Renovate PRs) instead of Flux image automation or central regex managers.
