locals {
  cluster_endpoint = "k8s.${var.networking.internal_tld}"
  cluster_path     = "${var.accounts.github.repository_path}/${var.name}"

  # Feature detection
  longhorn_enabled   = contains(var.features, "longhorn")
  spegel_enabled     = contains(var.features, "spegel")
  prometheus_enabled = contains(var.features, "prometheus")
  gateway_enabled    = contains(var.features, "gateway-api")

  # Filter machines belonging to this cluster
  cluster_machines = {
    for name, machine in var.machines :
    name => machine
    if machine.cluster == var.name
  }

  # Transform machines with feature-specific configuration
  machines = {
    for name, machine in local.cluster_machines :
    name => merge(machine, {
      install = merge(
        machine.install,
        {
          extensions        = concat(lookup(machine.install, "extensions", []), local.longhorn_enabled ? ["iscsi-tools", "util-linux-tools"] : [])
          extra_kernel_args = concat(lookup(machine.install, "extra_kernel_args", []), local.performance_kernel_args)
          selector          = lookup(machine.install, "selector", "")
          secureboot        = lookup(machine.install, "secureboot", false)
          architecture      = lookup(machine.install, "architecture", "amd64")
          platform          = lookup(machine.install, "platform", "metal")
          sbc               = lookup(machine.install, "sbc", "")
          wipe              = lookup(machine.install, "wipe", true)
        }
      )
      labels              = local.longhorn_enabled ? [local.longhorn_create_default_disk_label] : []
      kubelet_extraMounts = local.machine_kubelet_mounts[name]
      files               = local.spegel_enabled ? [local.spegel_containerd_config] : []
      annotations         = local.machine_longhorn_annotations[name]
    })
  }

  # Performance kernel args - disable security features for bare metal homelab
  performance_kernel_args = [
    "apparmor=0",
    "init_on_alloc=0",
    "init_on_free=0",
    "mitigations=off",
    "security=none"
  ]

  # Longhorn requires this label to auto-configure disks
  longhorn_create_default_disk_label = {
    key   = "node.longhorn.io/create-default-disk"
    value = "config"
  }

  # Spegel requires containerd to retain unpacked layers for p2p image sharing
  spegel_containerd_config = {
    path        = "/etc/cri/conf.d/20-customization.part"
    op          = "create"
    permissions = "0o666"
    content     = <<-EOT
      [plugins."io.containerd.cri.v1.images"]
        discard_unpacked_layers = false
    EOT
  }

  # Build kubelet mounts per machine: longhorn root + any additional disks
  machine_kubelet_mounts = {
    for name, machine in local.cluster_machines :
    name => concat(
      local.longhorn_enabled ? [{
        destination = "/var/lib/longhorn"
        type        = "bind"
        source      = "/var/lib/longhorn"
        options     = ["bind", "rshared", "rw"]
      }] : [],
      [for disk in lookup(machine, "disks", []) : {
        destination = disk.mountpoint
        type        = "bind"
        source      = disk.mountpoint
        options     = ["bind", "rshared", "rw"]
      }]
    )
  }

  # Build longhorn disk annotations per machine
  machine_longhorn_annotations = {
    for name, machine in local.cluster_machines :
    name => local.longhorn_enabled ? local.machine_disk_configs[name] : []
  }

  # Compute disk configurations for longhorn annotations
  machine_disk_configs = {
    for name, machine in local.cluster_machines :
    name => (
      lookup(lookup(machine.install, "data", {}), "enabled", false) || length(lookup(machine, "disks", [])) > 0
      ) ? [{
        key = "node.longhorn.io/default-disks-config"
        value = "'${jsonencode([
          for disk in concat(
            lookup(lookup(machine.install, "data", {}), "enabled", false) ? [{
              mountpoint = "/var/lib/longhorn"
              tags       = lookup(lookup(machine.install, "data", {}), "tags", [])
            }] : [],
            lookup(machine, "disks", [])
            ) : {
            name            = basename(disk.mountpoint)
            path            = disk.mountpoint
            storageReserved = 0
            allowScheduling = true
            tags            = lookup(disk, "tags", [])
          }
        ])}'"
    }] : []
  }

  # Prometheus requires these for metrics scraping
  prometheus_etcd_extraArgs = local.prometheus_enabled ? [
    { name = "listen-metrics-urls", value = "http://0.0.0.0:2381" }
  ] : []

  prometheus_controllerManager_extraArgs = local.prometheus_enabled ? [
    { name = "bind-address", value = "0.0.0.0" }
  ] : []

  prometheus_scheduler_extraArgs = local.prometheus_enabled ? [
    { name = "bind-address", value = "0.0.0.0" }
  ] : []

  prometheus_extraManifests = local.prometheus_enabled ? [
    "https://raw.githubusercontent.com/prometheus-community/helm-charts/refs/tags/prometheus-operator-crds-${var.versions.prometheus}/charts/kube-prometheus-stack/charts/crds/crds/crd-podmonitors.yaml",
    "https://raw.githubusercontent.com/prometheus-community/helm-charts/refs/tags/prometheus-operator-crds-${var.versions.prometheus}/charts/kube-prometheus-stack/charts/crds/crds/crd-servicemonitors.yaml",
    "https://raw.githubusercontent.com/prometheus-community/helm-charts/refs/tags/prometheus-operator-crds-${var.versions.prometheus}/charts/kube-prometheus-stack/charts/crds/crds/crd-probes.yaml",
    "https://raw.githubusercontent.com/prometheus-community/helm-charts/refs/tags/prometheus-operator-crds-${var.versions.prometheus}/charts/kube-prometheus-stack/charts/crds/crds/crd-prometheusrules.yaml",
  ] : []

  gateway_api_extraManifests = local.gateway_enabled ? [
    "https://github.com/kubernetes-sigs/gateway-api/releases/download/${var.versions.gateway_api}/experimental-install.yaml"
  ] : []

  # Build talos machines for the talos module
  talos_machines = [
    for name, machine in local.machines : {
      config = templatefile("${path.module}/resources/talos_machine.yaml.tftpl", {
        cluster_name                        = var.name
        cluster_endpoint                    = "https://${local.cluster_endpoint}:6443"
        cluster_node_subnet                 = var.networking.node_subnet
        cluster_pod_subnet                  = var.networking.pod_subnet
        cluster_service_subnet              = var.networking.service_subnet
        cluster_vip                         = var.networking.vip
        cluster_etcd_extraArgs              = local.prometheus_etcd_extraArgs
        cluster_controllerManager_extraArgs = local.prometheus_controllerManager_extraArgs
        cluster_scheduler_extraArgs         = local.prometheus_scheduler_extraArgs
        cluster_extraManifests              = concat(local.prometheus_extraManifests, local.gateway_api_extraManifests)
        machine_hostname                    = name
        machine_type                        = machine.type
        machine_interfaces                  = machine.interfaces
        machine_nameservers                 = var.networking.nameservers
        machine_timeservers                 = var.networking.timeservers
        machine_install                     = machine.install
        machine_disks                       = lookup(machine, "disks", [])
        machine_labels                      = machine.labels
        machine_annotations                 = machine.annotations
        machine_files                       = machine.files
        machine_kubelet_extraMounts         = machine.kubelet_extraMounts
      })
      install = {
        selector          = machine.install.selector
        extensions        = machine.install.extensions
        extra_kernel_args = machine.install.extra_kernel_args
        secureboot        = machine.install.secureboot
        architecture      = machine.install.architecture
        platform          = machine.install.platform
        sbc               = machine.install.sbc
      }
    }
  ]

  # Cilium values for bootstrap
  cilium_values = templatefile("${path.module}/resources/cilium_values.yaml.tftpl", {
    cluster_name       = var.name
    cluster_pod_subnet = var.networking.pod_subnet
    internal_domain    = var.networking.internal_tld
  })

  # Cluster environment variables for flux post-build substitution (non-version)
  cluster_vars = [
    { name = "cluster_name", value = var.name },
    { name = "cluster_tld", value = var.networking.internal_tld },
    { name = "cluster_endpoint", value = local.cluster_endpoint },
    { name = "cluster_vip", value = var.networking.vip },
    { name = "cluster_node_subnet", value = var.networking.node_subnet },
    { name = "cluster_pod_subnet", value = var.networking.pod_subnet },
    { name = "cluster_service_subnet", value = var.networking.service_subnet },
    { name = "cluster_path", value = local.cluster_path },
    { name = "default_replica_count", value = "\"${tostring(min(3, length(local.machines)))}\"" },
    { name = "cluster_id", value = tostring(var.networking.id) },
    { name = "cluster_ip_pool_start", value = var.networking.ip_pool_start },
    { name = "cluster_ip_pool_stop", value = var.networking.ip_pool_stop },
    { name = "internal_ingress_ip", value = var.networking.internal_ingress_ip },
    { name = "external_ingress_ip", value = var.networking.external_ingress_ip },
    { name = "internal_domain", value = var.networking.internal_tld },
    { name = "external_domain", value = var.networking.external_tld },
    { name = "cluster_l2_interfaces", value = jsonencode(distinct(flatten([for m in values(local.machines) : [for iface in m.interfaces : lookup(iface, "id", "") if lookup(iface, "id", "") != ""]]))) },
  ]

  # Version environment variables for flux post-build substitution
  version_vars = [
    { name = "talos_version", value = var.versions.talos },
    { name = "cilium_version", value = var.versions.cilium },
    { name = "flux_version", value = var.versions.flux },
    { name = "prometheus_version", value = var.versions.prometheus },
    { name = "kubernetes_version", value = var.versions.kubernetes },
  ]

  # DNS records for control plane nodes
  dns_records = {
    for name, machine in local.machines :
    name => {
      name   = local.cluster_endpoint
      record = machine.interfaces[0].addresses[0].ip
    }
    if machine.type == "controlplane"
  }

  # DHCP reservations for all cluster machines
  dhcp_reservations = {
    for name, machine in local.machines :
    name => {
      mac = machine.interfaces[0].hardwareAddr
      ip  = machine.interfaces[0].addresses[0].ip
    }
  }
  /*
  # SSM parameters to fetch
  params_get = toset([
    var.accounts.unifi.api_key_store,
    var.accounts.github.token_store,
    var.accounts.external_secrets.id_store,
    var.accounts.external_secrets.secret_store,
    var.accounts.healthchecksio.api_key_store,
  ])
*/
}
