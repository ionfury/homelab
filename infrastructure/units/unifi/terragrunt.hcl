locals {
  accounts_vars = read_terragrunt_config(find_in_parent_folders("accounts.hcl"))
}

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../.././/modules/unifi"
}

dependency "config" {
  config_path = "../config"

  mock_outputs = {
    unifi = {
      dns_records       = {}
      dhcp_reservations = {}
      port_forwards     = {}
      dynamic_dns       = {}
    }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

inputs = {
  dns_records       = dependency.config.outputs.unifi.dns_records
  dhcp_reservations = dependency.config.outputs.unifi.dhcp_reservations
  port_forwards     = dependency.config.outputs.unifi.port_forwards
  dynamic_dns       = dependency.config.outputs.unifi.dynamic_dns
  unifi             = local.accounts_vars.locals.accounts.unifi
}
