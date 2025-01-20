include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "common" {
  path   = "${dirname(find_in_parent_folders("root.hcl"))}/_common/bootstrap.hcl"
  expose = true
}

terraform {
  source = "${include.common.locals.base_source_url}?ref=v0.19.0"
}

dependency "credentials" {
  config_path = "../credentials"
}

dependency "cluster" {
  config_path = "../cluster"
}

inputs = {
  flux_version = "v2.4.0"
  github_token = dependency.credentials.outputs.values["/homelab/github/ionfury/homelab-flux-dev-token"]
  kubernetes_config_path = dependency.cluster.outputs.kubeconfig_filename
}
