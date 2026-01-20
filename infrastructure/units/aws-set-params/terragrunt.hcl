include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../.././/modules/aws-set-params"
}

dependency "config" {
  config_path = "../config"

  mock_outputs = {
    aws_set_params = {
      kubeconfig_path  = "/mock/kubeconfig"
      talosconfig_path = "/mock/talosconfig"
    }
    cluster_name = "mock"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

dependency "talos" {
  config_path = "../talos"

  mock_outputs = {
    kubeconfig_raw  = "mock"
    talosconfig_raw = "mock"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
  mock_outputs_merge_strategy_with_state  = "shallow"
}

inputs = {
  params = {
    kubeconfig = {
      name        = dependency.config.outputs.aws_set_params.kubeconfig_path
      description = "Kubeconfig for cluster '${dependency.config.outputs.cluster_name}'."
      type        = "SecureString"
      value       = dependency.talos.outputs.kubeconfig_raw
    }
    talosconfig = {
      name        = dependency.config.outputs.aws_set_params.talosconfig_path
      description = "Talosconfig for cluster '${dependency.config.outputs.cluster_name}'."
      type        = "SecureString"
      value       = dependency.talos.outputs.talosconfig_raw
    }
  }
}
