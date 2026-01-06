locals {
  networking_vars = read_terragrunt_config(find_in_parent_folders("networking.hcl"))
  inventory_vars  = read_terragrunt_config(find_in_parent_folders("inventory.hcl"))
  accounts_vars   = read_terragrunt_config(find_in_parent_folders("accounts.hcl"))

  versions = {
    talos       = "v1.10.0"
    kubernetes  = "1.32.0"
    cilium      = "1.16.5"
    gateway_api = "v1.2.1"
    flux        = "v2.4.0"
    prometheus  = "20.0.0"
  }

  local_paths = {
    talos      = "~/.talos"
    kubernetes = "~/.kube"
  }
}

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../.././/modules/config"
}
/*
dependency "aws_get_params" {
  config_path = "../aws-get-params"

  mock_outputs = {
    values = {}
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}
*/
inputs = {
  name        = values.name
  features    = values.features
  networking  = local.networking_vars.locals.clusters[values.name]
  machines    = local.inventory_vars.locals.hosts
  versions    = local.versions
  local_paths = local.local_paths
  accounts    = local.accounts_vars.locals.accounts
  //account_values = dependency.aws_get_params.outputs.values
}
