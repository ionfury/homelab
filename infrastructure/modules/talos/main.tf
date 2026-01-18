locals {
  cluster_config   = yamldecode(var.talos_machines[0].config).cluster
  cluster_name     = try(local.cluster_config.clusterName, "talos.local")
  cluster_endpoint = local.cluster_config.controlPlane.endpoint

  machines          = { for v in var.talos_machines : yamldecode(v.config).machine.network.hostname => v }
  addresses         = { for k, v in local.machines : k => split("/", yamldecode(v.config).machine.network.interfaces[0].addresses[0])[0] }
  machine_ips       = [for k, v in local.machines : local.addresses[k]]
  control_plane_ips = [for k, v in local.machines : local.addresses[k] if yamldecode(v.config).machine.type == "controlplane"]
  bootstrap_ip      = local.control_plane_ips[0]
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
  machine_type       = yamldecode(each.value.config).machine.type
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  kubernetes_version = var.kubernetes_version
  talos_version      = var.talos_version

  config_patches = concat(
    [each.value.config],
    [templatefile("${path.module}/resources/talos-patches/machine_install.yaml.tftpl", {
      machine_install_disk_image = each.value.install.secureboot ? local.machine_installer_secureboot[each.key] : local.machine_installer[each.key]
      machine_install_disk       = data.talos_machine_disks.this[each.key].disks[0].dev_path
    })],
    yamldecode(each.value.config).machine.type == "controlplane" && length(var.bootstrap_charts) > 0 ? [templatefile("${path.module}/resources/talos-patches/inline_manifests.yaml.tftpl", {
      machine_type = yamldecode(each.value.config).machine.type
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
