include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../.././/modules/talos"
}

dependency "config" {
  config_path = values.config_path

  mock_outputs = {
    talos = {
      talos_version          = "v1.10.0"
      kubernetes_version     = "1.32.0"
      talos_machines         = []
      on_destroy             = { graceful = false, reboot = true, reset = true }
      talos_config_path      = "~/.talos"
      kubernetes_config_path = "~/.kube"
      talos_timeout          = "10m"
    }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  talos_version          = dependency.config.outputs.talos.talos_version
  kubernetes_version     = dependency.config.outputs.talos.kubernetes_version
  talos_machines         = dependency.config.outputs.talos.talos_machines
  on_destroy             = dependency.config.outputs.talos.on_destroy
  talos_config_path      = dependency.config.outputs.talos.talos_config_path
  kubernetes_config_path = dependency.config.outputs.talos.kubernetes_config_path
  talos_timeout          = dependency.config.outputs.talos.talos_timeout
}
