include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../.././/modules/bootstrap"
}

dependency "config" {
  config_path = values.config_path

  mock_outputs = {
    bootstrap = {
      cluster_name     = "mock"
      flux_version     = "v2.4.0"
      cluster_env_vars = []
      github = {
        org             = "mock"
        repository      = "mock"
        repository_path = "mock"
        token           = "mock"
      }
      external_secrets = {
        id     = "mock"
        secret = "mock"
      }
      healthchecksio = {
        api_key = "mock"
      }
    }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

dependency "talos" {
  config_path = values.talos_path

  mock_outputs = {
    kubeconfig_host                   = "https://localhost:6443"
    kubeconfig_client_certificate     = "mock"
    kubeconfig_client_key             = "mock"
    kubeconfig_cluster_ca_certificate = "mock"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  cluster_name     = dependency.config.outputs.bootstrap.cluster_name
  flux_version     = dependency.config.outputs.bootstrap.flux_version
  cluster_env_vars = dependency.config.outputs.bootstrap.cluster_env_vars
  github           = dependency.config.outputs.bootstrap.github
  external_secrets = dependency.config.outputs.bootstrap.external_secrets
  healthchecksio   = dependency.config.outputs.bootstrap.healthchecksio
  kubeconfig = {
    host                   = dependency.talos.outputs.kubeconfig_host
    client_certificate     = dependency.talos.outputs.kubeconfig_client_certificate
    client_key             = dependency.talos.outputs.kubeconfig_client_key
    cluster_ca_certificate = dependency.talos.outputs.kubeconfig_cluster_ca_certificate
  }
}
