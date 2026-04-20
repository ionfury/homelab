locals {
  networking_vars = read_terragrunt_config(find_in_parent_folders("networking.hcl"))
  accounts_vars   = read_terragrunt_config(find_in_parent_folders("accounts.hcl"))

  live = local.networking_vars.locals.clusters.live
}

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../.././/modules/unifi-gateway"
}

inputs = {
  port_forwards = {
    external_gateway_http = {
      name     = "External Gateway HTTP"
      dst_port = "80"
      fwd_ip   = local.live.external_ingress_ip
      fwd_port = "80"
      protocol = "tcp"
    }
    external_gateway_https = {
      name     = "External Gateway HTTPS"
      dst_port = "443"
      fwd_ip   = local.live.external_ingress_ip
      fwd_port = "443"
      protocol = "tcp"
    }
  }
  unifi = local.accounts_vars.locals.accounts.unifi
}
