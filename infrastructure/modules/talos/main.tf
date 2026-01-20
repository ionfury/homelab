locals {
  # Parse all machines - extract hostname from HostnameConfig, main config, and bond config
  parsed_machines = [
    for v in var.talos_machines : {
      hostname     = [for c in v.configs : yamldecode(c).hostname if can(yamldecode(c).kind) && yamldecode(c).kind == "HostnameConfig"][0]
      main_config  = [for c in v.configs : yamldecode(c) if can(yamldecode(c).machine.type)][0]
      bond_configs = [for c in v.configs : yamldecode(c) if can(yamldecode(c).kind) && yamldecode(c).kind == "BondConfig"]
      original     = v
    }
  ]

  # Create maps keyed by hostname
  machine_main_configs = { for m in local.parsed_machines : m.hostname => m.main_config }
  machines             = { for m in local.parsed_machines : m.hostname => m.original }

  # Extract IP addresses from BondConfig (first bond, first address, strip CIDR)
  addresses         = { for m in local.parsed_machines : m.hostname => split("/", m.bond_configs[0].addresses[0].address)[0] }
  machine_ips       = [for m in local.parsed_machines : local.addresses[m.hostname]]
  control_plane_ips = [for m in local.parsed_machines : local.addresses[m.hostname] if m.main_config.machine.type == "controlplane"]
  bootstrap_ip      = local.control_plane_ips[0]

  cluster_config   = local.machine_main_configs[keys(local.machine_main_configs)[0]].cluster
  cluster_name     = try(local.cluster_config.clusterName, "talos.local")
  cluster_endpoint = local.cluster_config.controlPlane.endpoint
}

data "helm_template" "bootstrap_charts" {
  for_each = { for chart in var.bootstrap_charts : chart.name => chart }

  repository   = each.value.repository
  chart        = each.value.chart
  name         = each.value.name
  version      = each.value.version
  namespace    = each.value.namespace
  kube_version = var.kubernetes_version
  values       = [each.value.values]
}

resource "talos_machine_secrets" "this" {
  talos_version = var.talos_version
}

data "talos_machine_disks" "this" {
  for_each = local.machines

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.addresses[each.key]
  selector             = local.machines[each.key].install.selector
}

data "talos_machine_configuration" "this" {
  for_each = local.machines

  cluster_name       = local.cluster_name
  cluster_endpoint   = local.cluster_endpoint
  machine_type       = local.machine_main_configs[each.key].machine.type
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  kubernetes_version = var.kubernetes_version
  talos_version      = var.talos_version

  config_patches = concat(
    each.value.configs,
    [templatefile("${path.module}/resources/talos-patches/machine_install.yaml.tftpl", {
      machine_install_disk_image = each.value.install.secureboot ? local.machine_installer_secureboot[each.key] : local.machine_installer[each.key]
      machine_install_disk       = data.talos_machine_disks.this[each.key].disks[0].dev_path
    })],
    local.machine_main_configs[each.key].machine.type == "controlplane" && length(var.bootstrap_charts) > 0 ? [templatefile("${path.module}/resources/talos-patches/inline_manifests.yaml.tftpl", {
      machine_type = local.machine_main_configs[each.key].machine.type
      manifests    = data.helm_template.bootstrap_charts
    })] : []
  )
}

data "talos_client_configuration" "this" {
  cluster_name         = local.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = local.control_plane_ips
  nodes                = local.machine_ips
}
