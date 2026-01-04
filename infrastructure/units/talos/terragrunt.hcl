include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../.././/modules/talos"
}

dependency "config" {
  config_path = "../config"

  mock_outputs = {
    talos = {
      talos_version          = "v1.10.0"
      kubernetes_version     = "1.32.0"
      talos_machines         = []
      on_destroy             = { graceful = false, reboot = true, reset = true }
      talos_config_path      = "~/.talos"
      kubernetes_config_path = "~/.kube"
      talos_timeout          = "10m"
      bootstrap_charts       = []
    }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = dependency.config.outputs.talos
