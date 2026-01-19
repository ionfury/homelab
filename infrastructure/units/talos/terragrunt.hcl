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
          hostname         = "mock-controlplane-1"
          machine_type     = "controlplane"
          cluster_name     = "talos.local"
          cluster_endpoint = "https://talos.local:6443"
          address          = "10.10.10.10"
          config_patches   = ["cluster:\n  clusterName: talos.local"]
          install          = { selector = "disk.model = *" }
        }
      ]
      on_destroy             = { graceful = false, reboot = true, reset = true }
      talos_config_path      = "~/.talos"
      kubernetes_config_path = "~/.kube"
      talos_timeout          = "10m"
      bootstrap_charts       = []
    }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

inputs = dependency.config.outputs.talos
