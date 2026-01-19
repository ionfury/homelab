locals {
  # Use structured metadata from config module (avoids yamldecode on multi-doc YAML)
  cluster_name     = var.talos_machines[0].cluster_name
  cluster_endpoint = var.talos_machines[0].cluster_endpoint

  machines          = { for v in var.talos_machines : v.hostname => v }
  addresses         = { for k, v in local.machines : k => v.address }
  machine_ips       = [for k, v in local.machines : v.address]
  control_plane_ips = [for k, v in local.machines : v.address if v.machine_type == "controlplane"]
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
  machine_type       = each.value.machine_type
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  kubernetes_version = var.kubernetes_version
  talos_version      = var.talos_version

  # config_patches is a list of YAML documents - each element is a separate patch
  config_patches = concat(
    each.value.config_patches,
    [templatefile("${path.module}/resources/talos-patches/machine_install.yaml.tftpl", {
      machine_install_disk_image = each.value.install.secureboot ? local.machine_installer_secureboot[each.key] : local.machine_installer[each.key]
      machine_install_disk       = data.talos_machine_disks.this[each.key].disks[0].dev_path
    })],
    each.value.machine_type == "controlplane" && length(var.bootstrap_charts) > 0 ? [templatefile("${path.module}/resources/talos-patches/inline_manifests.yaml.tftpl", {
      machine_type = each.value.machine_type
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
