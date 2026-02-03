resource "talos_machine_configuration_apply" "machines" {
  for_each = local.machines

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.this[each.key].machine_configuration
  node                        = local.addresses[each.key]

  on_destroy = {
    graceful              = var.on_destroy.graceful
    reboot                = var.on_destroy.reboot
    reset                 = var.on_destroy.reset
    system_labels_to_wipe = var.on_destroy.system_labels_to_wipe
    user_disks_to_wipe    = var.on_destroy.user_disks_to_wipe
  }
}

resource "talos_machine_bootstrap" "this" {
  depends_on = [talos_machine_configuration_apply.machines]

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.bootstrap_ip
}

resource "talos_cluster_kubeconfig" "this" {
  depends_on = [talos_machine_bootstrap.this]

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.bootstrap_ip
}
