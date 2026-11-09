# Talos and Kubernetes upgrades run in-cluster through tuppr

Running clusters are upgraded by tuppr `TalosUpgrade` and `KubernetesUpgrade` resources driven by `versions.env`, not by `terragrunt apply`. Version bumps then flow through the same PR, OCI artifact and Flux path as every other change; Terragrunt still reads the same versions for install-time configuration.
