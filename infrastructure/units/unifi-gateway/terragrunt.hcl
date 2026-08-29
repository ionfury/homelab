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
  dynamic_dns = {
    external_gateway = {
      service        = "cloudflare"
      host_name      = "gw.${local.live.external_tld}"
      server         = ""
      login          = local.live.external_tld
      password_store = local.accounts_vars.locals.accounts.cloudflare.api_token_store
    }
  }
  unifi = local.accounts_vars.locals.accounts.unifi
}
