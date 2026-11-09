# The platform is flux-operator ResourceSets generated from one input list

Platform Helm releases are inputs to a single flux-operator `ResourceSet` whose template stamps out an identical HelmRepository, HelmRelease (in `flux-system`, with `targetNamespace`) and wrapper Kustomization per chart, with values supplied from ConfigMaps. The HelmRelease scaffold then exists exactly once, and every cluster is a variable-substituted copy of the same platform.

## Consequences

Flux Kustomizations cannot depend on HelmReleases, so each chart gets an otherwise empty wrapper Kustomization that health-checks it, giving config Kustomizations something to `dependsOn`.
