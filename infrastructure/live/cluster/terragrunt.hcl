include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "common" {
  path   = "${dirname(find_in_parent_folders("root.hcl"))}/_common/talos-cluster.hcl"
  expose = true
}

terraform {
  source = "${include.common.locals.base_source_url}?ref=v0.28.0"
}

dependencies {
  paths = ["../dns", "../users"]
}

inputs = {
  cluster_vip        = "192.168.10.69"
  talos_version      = "v1.9.3"
  kubernetes_version = "1.32.1"
  cilium_version     = "1.16.5"
  cilium_values      = file("${get_terragrunt_dir()}/../../../kubernetes/manifests/helm-release/cilium/values.yaml")

  cluster_extraManifests = [
    # Prometheus manifests
    "https://raw.githubusercontent.com/prometheus-community/helm-charts/refs/tags/prometheus-operator-crds-17.0.2/charts/kube-prometheus-stack/charts/crds/crds/crd-podmonitors.yaml",
    "https://raw.githubusercontent.com/prometheus-community/helm-charts/refs/tags/prometheus-operator-crds-17.0.2/charts/kube-prometheus-stack/charts/crds/crds/crd-servicemonitors.yaml",
    "https://raw.githubusercontent.com/prometheus-community/helm-charts/refs/tags/prometheus-operator-crds-17.0.2/charts/kube-prometheus-stack/charts/crds/crds/crd-probes.yaml",
    "https://raw.githubusercontent.com/prometheus-community/helm-charts/refs/tags/prometheus-operator-crds-17.0.2/charts/kube-prometheus-stack/charts/crds/crds/crd-prometheusrules.yaml",
  ]

  # The following are needed to scrape metrics for kube-prometheus-metrics
  cluster_etcd_extraArgs = [{
    name  = "listen-metrics-urls"
    value = "http://0.0.0.0:2381"
  }]
  cluster_controllerManager_extraArgs = [{
    name = "bind-address"
    value = "0.0.0.0"
  }]
  cluster_scheduler_extraArgs = [{
    name = "bind-address"
    value = "0.0.0.0"
  }]


  machine_kubelet_extraMounts = [
    # Support Longhorn: https://longhorn.io/docs/1.7.2/advanced-resources/os-distro-specific/talos-linux-support/#data-path-mounts
    {
      destination = "/var/lib/longhorn"
      type = "bind"
      source = "/var/lib/longhorn"
      options = [
        "bind",
        "rshared",
        "rw",
      ]
    },
    {
      destination = "/var/mnt/disk2"
      type = "bind"
      source = "/var/mnt/disk2"
      options = [
        "bind",
        "rshared",
        "rw",
      ]
    }
  ]

  machine_files = [
    # Support Spegal: https://spegel.dev/docs/getting-started/#talos
    {
      path = "/etc/cri/conf.d/20-customization.part"
      op = "create"
      permissions = "0o666"
      content = <<-EOT
        [plugins."io.containerd.cri.v1.images"]
          discard_unpacked_layers = false
      EOT
    }
  ]

  machine_extensions = [
    # Support Longhorn: https://longhorn.io/docs/1.7.2/advanced-resources/os-distro-specific/talos-linux-support/#system-extensions
    "iscsi-tools",
    "util-linux-tools",
  ]

  machine_extra_kernel_args = [
    "apparmor=0",
    "init_on_alloc=0",
    "init_on_free=0",
    "mitigations=off",
    "security=none"
  ]
}
