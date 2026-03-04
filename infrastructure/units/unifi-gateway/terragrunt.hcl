locals {
  networking_vars = read_terragrunt_config(find_in_parent_folders("networking.hcl"))
  accounts_vars   = read_terragrunt_config(find_in_parent_folders("accounts.hcl"))
}

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../.././/modules/unifi-gateway"
}

inputs = {
  external_ingress_ip = local.networking_vars.locals.clusters.live.external_ingress_ip
  external_tld        = local.networking_vars.locals.clusters.live.external_tld
  unifi               = local.accounts_vars.locals.accounts.unifi
}
