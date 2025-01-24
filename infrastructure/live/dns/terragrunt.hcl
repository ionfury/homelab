include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "common" {
  path   = "${dirname(find_in_parent_folders("root.hcl"))}/_common/unifi-dns.hcl"
  expose = true
}


terraform {
  source = "${include.common.locals.base_source_url}?ref=v0.22.0"

  extra_arguments "no_refresh" {
    commands  = ["plan", "apply"]
    arguments = ["-refresh=false"]
  }
}

dependency "credentials" {
  config_path = "../credentials"
}

inputs = {
  unifi_username = dependency.credentials.outputs.values["/homelab/unifi/terraform/username"]
  unifi_password = dependency.credentials.outputs.values["/homelab/unifi/terraform/password"]
}
