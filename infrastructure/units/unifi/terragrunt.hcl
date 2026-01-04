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
      address           = "https://localhost"
      site              = "default"
      api_key           = "mock"
    }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  dns_records       = dependency.config.outputs.unifi.dns_records
  dhcp_reservations = dependency.config.outputs.unifi.dhcp_reservations
  unifi = {
    address = dependency.config.outputs.unifi.address
    site    = dependency.config.outputs.unifi.site
    api_key = dependency.config.outputs.unifi.api_key
  }
}
