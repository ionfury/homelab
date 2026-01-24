locals {
  accounts_vars = read_terragrunt_config(find_in_parent_folders("accounts.hcl"))

  # OCI artifact configuration for non-dev clusters
  github_org  = local.accounts_vars.locals.accounts.github.org
  github_repo = local.accounts_vars.locals.accounts.github.repository
}

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../.././/modules/bootstrap"
}

dependency "config" {
  config_path = "../config"

  mock_outputs = {
    bootstrap = {
      cluster_name = "mock"
      flux_version = "v2.4.0"
      cluster_vars = []
      version_vars = []
    }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

dependency "talos" {
  config_path = "../talos"

  mock_outputs = {
    kubeconfig_host                   = "https://localhost:6443"
    kubeconfig_client_certificate     = "mock"
    kubeconfig_client_key             = "mock"
    kubeconfig_cluster_ca_certificate = "mock"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
  mock_outputs_merge_strategy_with_state  = "shallow"
}

inputs = {
  cluster_name     = dependency.config.outputs.bootstrap.cluster_name
  flux_version     = dependency.config.outputs.bootstrap.flux_version
  cluster_vars     = dependency.config.outputs.bootstrap.cluster_vars
  version_vars     = dependency.config.outputs.bootstrap.version_vars
  github           = local.accounts_vars.locals.accounts.github
  external_secrets = local.accounts_vars.locals.accounts.external_secrets
  healthchecksio   = local.accounts_vars.locals.accounts.healthchecksio
  kubeconfig = {
    host                   = dependency.talos.outputs.kubeconfig_host
    client_certificate     = dependency.talos.outputs.kubeconfig_client_certificate
    client_key             = dependency.talos.outputs.kubeconfig_client_key
    cluster_ca_certificate = dependency.talos.outputs.kubeconfig_cluster_ca_certificate
  }

  # OCI artifact promotion - dev uses git, integration/live use OCI artifacts
  source_type     = dependency.config.outputs.bootstrap.cluster_name == "dev" ? "git" : "oci"
  oci_url         = dependency.config.outputs.bootstrap.cluster_name != "dev" ? "oci://ghcr.io/${local.github_org}/${local.github_repo}/platform" : ""
  oci_tag_pattern = dependency.config.outputs.bootstrap.cluster_name == "integration" ? "integration-*" : (dependency.config.outputs.bootstrap.cluster_name == "live" ? "validated-*" : "")
}
