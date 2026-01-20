# Storage size mappings by provisioning mode
locals {
  storage_sizes = {
    normal = {
      garage_data = "100Gi"
      garage_meta = "10Gi"
      database    = "20Gi"
      loki        = "50Gi"
    }
    minimal = {
      garage_data = "10Gi"
      garage_meta = "2Gi"
      database    = "5Gi"
      loki        = "10Gi"
    }
  }

  selected_sizes = local.storage_sizes[var.storage_provisioning]
}

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

  # Generate link aliases per machine (one per physical MAC address in bonds)
  machine_link_aliases = {
    for name, machine in local.cluster_machines :
    name => flatten([
      for bond_idx, bond in machine.bonds : [
        for link_idx, mac in bond.link_permanentAddr : {
          name           = "link${bond_idx}_${link_idx}"
          permanent_addr = mac
        } if mac != ""
      ]
    ])
  }

  # Build kubelet mounts per machine: longhorn root + any additional volumes
  machine_kubelet_mounts = {
    for name, machine in local.cluster_machines :
    name => concat(
      # System disk volume gets /var/lib/longhorn mount
      local.longhorn_enabled && anytrue([for v in lookup(machine, "volumes", []) : v.selector == "system_disk == true"]) ? [{
        destination = "/var/lib/longhorn"
        type        = "bind"
        source      = "/var/lib/longhorn"
        options     = ["bind", "rshared", "rw"]
      }] : [],
      # Non-system volumes get mounts at /var/mnt/<name>
      [for vol in lookup(machine, "volumes", []) : {
        destination = "/var/mnt/${vol.name}"
        type        = "bind"
        source      = "/var/mnt/${vol.name}"
        options     = ["bind", "rshared", "rw"]
      } if vol.selector != "system_disk == true"]
    )
  }

  # Build longhorn disk annotations per machine from volumes
  machine_longhorn_annotations = {
    for name, machine in local.cluster_machines :
    name => local.longhorn_enabled && length(lookup(machine, "volumes", [])) > 0 ? [{
      key = "node.longhorn.io/default-disks-config"
      value = "'${jsonencode([
        for vol in machine.volumes : {
          name            = vol.name
          path            = vol.selector == "system_disk == true" ? "/var/lib/longhorn" : "/var/mnt/${vol.name}"
          storageReserved = 0
          allowScheduling = true
          tags            = vol.tags
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

  # Build talos machines for the talos module - each machine has configs[] array of separate YAML documents
  talos_machines = [
    for name, machine in local.machines : {
      configs = compact(concat(
        # Document 1: Main machine config (NO interfaces, NO disks - those are in separate documents)
        [templatefile("${path.module}/resources/talos/talos_machine.yaml.tftpl", {
          cluster_name                        = var.name
          cluster_endpoint                    = "https://${local.cluster_endpoint}:6443"
          cluster_node_subnet                 = var.networking.node_subnet
          cluster_pod_subnet                  = var.networking.pod_subnet
          cluster_service_subnet              = var.networking.service_subnet
          cluster_etcd_extraArgs              = local.prometheus_etcd_extraArgs
          cluster_controllerManager_extraArgs = local.prometheus_controllerManager_extraArgs
          cluster_scheduler_extraArgs         = local.prometheus_scheduler_extraArgs
          cluster_extraManifests              = concat(local.prometheus_extraManifests, local.gateway_api_extraManifests)
          machine_type                        = machine.type
          machine_install                     = machine.install
          machine_labels                      = machine.labels
          machine_annotations                 = machine.annotations
          machine_files                       = machine.files
          machine_kubelet_extraMounts         = machine.kubelet_extraMounts
        })],

        # HostnameConfig document
        [templatefile("${path.module}/resources/talos/hostname_config.yaml.tftpl", {
          hostname = name
        })],

        # LinkAliasConfig for each physical link in bonds
        [for link in local.machine_link_aliases[name] :
          templatefile("${path.module}/resources/talos/link_alias_config.yaml.tftpl", { link = link })
        ],

        # BondConfig for each bond
        [for bond_idx, bond in machine.bonds :
          templatefile("${path.module}/resources/talos/bond_config.yaml.tftpl", {
            bond = {
              name      = "bond${bond_idx}"
              links     = [for i, _ in bond.link_permanentAddr : "link${bond_idx}_${i}"]
              bondMode  = bond.mode
              mtu       = bond.mtu
              addresses = bond.addresses
            }
          })
        ],

        # VLANConfig for each VLAN on each bond
        flatten([for bond_idx, bond in machine.bonds : [
          for vlan in lookup(bond, "vlans", []) :
          templatefile("${path.module}/resources/talos/vlan_config.yaml.tftpl", {
            bond_name = "bond${bond_idx}"
            vlan      = vlan
            mtu       = bond.mtu
          })
        ]]),

        # DHCPv4Config for each bond
        [for bond_idx, bond in machine.bonds :
          templatefile("${path.module}/resources/talos/dhcp_v4_config.yaml.tftpl", {
            bond = { name = "bond${bond_idx}" }
          })
        ],

        # Layer2VIPConfig for controlplane (first bond only)
        machine.type == "controlplane" && var.networking.vip != "" ? [
          templatefile("${path.module}/resources/talos/layer2_vip_config.yaml.tftpl", {
            cluster_vip = var.networking.vip
            bond_name   = "bond0"
          })
        ] : [],

        # VolumeConfig for EPHEMERAL - limit size when user volumes target system disk
        # This must come BEFORE UserVolumeConfig so EPHEMERAL doesn't consume all space
        anytrue([for v in lookup(machine, "volumes", []) : v.selector == "system_disk == true"]) ? [
          templatefile("${path.module}/resources/talos/ephemeral_volume_config.yaml.tftpl", {
            # Calculate EPHEMERAL maxSize: 100% minus sum of system disk user volume sizes
            max_size = "${100 - sum([for v in lookup(machine, "volumes", []) : tonumber(trimspace(trimsuffix(v.maxSize, "%"))) if v.selector == "system_disk == true"])}%"
          })
        ] : [],

        # UserVolumeConfig for each volume
        [for volume in lookup(machine, "volumes", []) :
          templatefile("${path.module}/resources/talos/user_volume_config.yaml.tftpl", { volume = volume })
        ],

        # Nameservers
        [templatefile("${path.module}/resources/talos/resolver_config.yaml.tftpl", {
          machine_nameservers = var.networking.nameservers
        })],

        # Timeservers
        [templatefile("${path.module}/resources/talos/time_sync_config.yaml.tftpl", {
          machine_timeservers = var.networking.timeservers
        })]
      ))
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
    { name = "default_replica_count", value = tostring(min(3, length(local.machines))) },
    # YAML-safe string version for StorageClass parameters (must be strings, not integers)
    { name = "storage_replica_count", value = "\"${tostring(min(3, length(local.machines)))}\"" },
    { name = "cluster_id", value = tostring(var.networking.id) },
    { name = "cluster_ip_pool_start", value = var.networking.ip_pool_start },
    { name = "cluster_ip_pool_stop", value = var.networking.ip_pool_stop },
    { name = "internal_ingress_ip", value = var.networking.internal_ingress_ip },
    { name = "external_ingress_ip", value = var.networking.external_ingress_ip },
    { name = "internal_domain", value = var.networking.internal_tld },
    { name = "external_domain", value = var.networking.external_tld },
    { name = "cluster_l2_interfaces", value = jsonencode(distinct(flatten([for m in values(local.machines) : [for bond_idx, _ in m.bonds : "bond${bond_idx}"]]))) },
    # Storage provisioning - volume sizes based on cluster mode
    { name = "storage_provisioning", value = var.storage_provisioning },
    { name = "garage_data_volume_size", value = local.selected_sizes.garage_data },
    { name = "garage_meta_volume_size", value = local.selected_sizes.garage_meta },
    { name = "database_volume_size", value = local.selected_sizes.database },
    { name = "loki_volume_size", value = local.selected_sizes.loki },
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
      record = machine.bonds[0].addresses[0]
    }
    if machine.type == "controlplane"
  }

  # DHCP reservations for all cluster machines
  dhcp_reservations = {
    for name, machine in local.machines :
    name => {
      mac = machine.bonds[0].link_permanentAddr[0]
      ip  = machine.bonds[0].addresses[0]
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
