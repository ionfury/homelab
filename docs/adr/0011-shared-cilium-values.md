# Cilium values are shared by the bootstrap install and Flux

`kubernetes/platform/charts/cilium.yaml` is the single values file used both by Terragrunt to install Cilium at Talos bootstrap, before Flux exists, and by Flux's HelmRelease afterwards. This prevents the CNI configuration from drifting between bootstrap and steady state.
