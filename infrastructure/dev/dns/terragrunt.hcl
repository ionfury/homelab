include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "common" {
  path   = "${dirname(find_in_parent_folders("root.hcl"))}/_common/unifi-dns.hcl"
  expose = true
}

terraform {
  source = "${include.common.locals.base_source_url}?ref=v0.10.0"

  /*
Provider bug as follows.  Wait/contribute to the following PR to fix: https://github.com/paultyng/terraform-provider-unifi/pull/468

* Failed to execute "tofu apply" in ./.terragrunt-cache/4dH1EW83I3IIZmLkJfrO70vTREg/m8XUUckwJF_wNW9OSXJ_jna-hCs/modules/unifi-dns
  ╷
  │ Error: invalid character '<' looking for beginning of value
  │
  │   with unifi_dns_record.record["node45"],
  │   on main.tf line 1, in resource "unifi_dns_record" "record":
  │    1: resource "unifi_dns_record" "record" {
  │
  ╵
  ╷
  │ Error: invalid character '<' looking for beginning of value
  │
  │   with unifi_dns_record.record["node44"],
  │   on main.tf line 1, in resource "unifi_dns_record" "record":
  │    1: resource "unifi_dns_record" "record" {
  │
  ╵
  ╷
  │ Error: invalid character '<' looking for beginning of value
  │
  │   with unifi_dns_record.record["node46"],
  │   on main.tf line 1, in resource "unifi_dns_record" "record":
  │    1: resource "unifi_dns_record" "record" {
  │
  ╵

  exit status 1
*/

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
