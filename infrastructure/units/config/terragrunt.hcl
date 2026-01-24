locals {
  networking_vars = read_terragrunt_config(find_in_parent_folders("networking.hcl"))
  inventory_vars  = read_terragrunt_config(find_in_parent_folders("inventory.hcl"))
  accounts_vars   = read_terragrunt_config(find_in_parent_folders("accounts.hcl"))
  versions_vars   = read_terragrunt_config(find_in_parent_folders("versions.hcl"))

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

inputs = {
  name                   = values.name
  features               = values.features
  storage_provisioning   = values.storage_provisioning
  networking             = local.networking_vars.locals.clusters[values.name]
  machines               = local.inventory_vars.locals.hosts
  versions               = local.versions_vars.locals.versions
  local_paths            = local.local_paths
  accounts               = local.accounts_vars.locals.accounts
  cilium_values_template = file("${get_repo_root()}/kubernetes/platform/charts/cilium.yaml")
}
