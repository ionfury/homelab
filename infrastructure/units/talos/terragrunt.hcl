include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../.././/modules/talos"
}

dependency "unifi" {
  config_path = "../unifi"

  mock_outputs                            = {}
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
  skip_outputs                            = true
}

dependency "config" {
  config_path = "../config"

  mock_outputs = {
    talos = {
      talos_version      = "v1.12.0"
      kubernetes_version = "1.34.0"
      talos_machines = [
        {
          install = { selector = "disk.model = *", secureboot = false }
          configs = [
            <<-EOT
            kind: HostnameConfig
            hostname: mock-controlplane-1
            EOT
            ,
            <<-EOT
            kind: BondConfig
            addresses:
              - address: 10.10.10.10/24
            EOT
            ,
            <<-EOT
            cluster:
              clusterName: talos.local
              controlPlane:
                endpoint: https://talos.local:6443
            machine:
              type: controlplane
            EOT
          ]
        }
      ]
      on_destroy             = { graceful = false, reboot = true, reset = true, system_labels_to_wipe = ["STATE", "EPHEMERAL"], user_disks_to_wipe = ["system_disk"] }
      talos_config_path      = "~/.talos"
      kubernetes_config_path = "~/.kube"
      talos_timeout          = "10m"
      bootstrap_charts       = []
    }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

inputs = dependency.config.outputs.talos
