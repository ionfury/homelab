locals {
  networking_vars = read_terragrunt_config(find_in_parent_folders("networking.hcl"))
  inventory_vars  = read_terragrunt_config(find_in_parent_folders("inventory.hcl"))
  accounts_vars   = read_terragrunt_config(find_in_parent_folders("accounts.hcl"))

  # Parse platform versions.env file (single source of truth for ALL versions)
  platform_versions_raw = file("${get_repo_root()}/kubernetes/platform/versions.env")
  platform_versions = {
    for line in compact(split("\n", local.platform_versions_raw)) :
    split("=", line)[0] => split("=", line)[1]
    if !startswith(trimspace(line), "#") && length(split("=", line)) == 2
  }

  # Map to versions object expected by modules
  versions = {
    talos       = local.platform_versions["talos_version"]
    kubernetes  = local.platform_versions["kubernetes_version"]
    cilium      = local.platform_versions["cilium_version"]
    flux        = local.platform_versions["flux_version"]
    gateway_api = local.platform_versions["gateway_api_version"]
    prometheus  = local.platform_versions["prometheus_version"]
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

inputs = {
  name                   = values.name
  features               = values.features
  storage_provisioning   = values.storage_provisioning
  on_destroy             = try(values.on_destroy, null)
  networking             = local.networking_vars.locals.clusters[values.name]
  machines               = local.inventory_vars.locals.hosts
  versions               = local.versions
  local_paths            = local.local_paths
  accounts               = local.accounts_vars.locals.accounts
  cilium_values_template = file("${get_repo_root()}/kubernetes/platform/charts/cilium.yaml")
}
