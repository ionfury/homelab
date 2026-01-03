# This completes when the cluster is ready to be upgraded.
/*
resource "null_resource" "talos_cluster_health" {
  depends_on = [talos_machine_bootstrap.this, talos_machine_configuration_apply.machines]
  for_each   = toset(local.control_plane_ips)

  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = "talosctl --talosconfig $TALOSCONFIG health -n $NODE -e $NODE --wait-timeout $TIMEOUT"

    environment = {
      TALOSCONFIG = local_sensitive_file.talosconfig.filename
      NODE        = each.key
      TIMEOUT     = var.talos_timeout
    }
  }
}
*/

# Hack: https://github.com/siderolabs/terraform-provider-talos/issues/140
# This upgrades the cluster
resource "null_resource" "talos_upgrade_trigger" {
  #depends_on = [null_resource.talos_cluster_health]

  depends_on = [talos_machine_bootstrap.this, talos_machine_configuration_apply.machines]
  for_each   = local.machines

  triggers = {
    desired_talos_tag    = local.machine_talos_version[each.key]
    desired_schematic_id = local.machine_schematic_id[each.key]
  }

  # Should only upgrade if there's a schematic mismatch
  provisioner "local-exec" {
    command = "flock $LOCK_FILE --command ${path.module}/resources/scripts/upgrade-node.sh"

    environment = {
      LOCK_FILE = "${path.module}/resources/.upgrade-node.lock"

      DESIRED_TALOS_TAG       = self.triggers.desired_talos_tag
      DESIRED_TALOS_SCHEMATIC = self.triggers.desired_schematic_id
      TALOS_CONFIG_PATH       = local_sensitive_file.talosconfig.filename
      TALOS_NODE              = local.addresses[each.key]
      TIMEOUT                 = var.talos_timeout
    }
  }
}

# This completes when the upgrade is complete.
resource "null_resource" "talos_cluster_health_upgrade" {
  depends_on = [null_resource.talos_upgrade_trigger]

  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = "talosctl --talosconfig $TALOSCONFIG health -n $NODE -e $NODE --wait-timeout $TIMEOUT"

    environment = {
      TALOSCONFIG = local_sensitive_file.talosconfig.filename
      NODE        = local.bootstrap_ip
      TIMEOUT     = var.talos_timeout
    }
  }
}
