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
    }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

inputs = {
  dns_records       = dependency.config.outputs.unifi.dns_records
  dhcp_reservations = dependency.config.outputs.unifi.dhcp_reservations
  unifi             = local.accounts_vars.locals.accounts.unifi
}
