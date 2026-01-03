locals {
  repo_root  = get_repo_root()
  infra_path = "${local.repo_root}/infrastructure"

  networking = read_terragrunt_config("${local.infra_path}/networking.hcl")
  inventory  = read_terragrunt_config("${local.infra_path}/inventory.hcl")
  accounts   = read_terragrunt_config("${local.infra_path}/accounts.hcl")

  cluster_name       = "${basename(get_terragrunt_dir())}"
  cluster_networking = local.networking.locals.clusters[local.cluster_name]

  versions = {
    talos       = "v1.10.0"
    kubernetes  = "1.32.0"
    cilium      = "1.16.5"
    gateway_api = "v1.2.1"
    flux        = "v2.4.0"
    prometheus  = "20.0.0"
  }

  local_paths = {
    talos      = "~/.talos"
    kubernetes = "~/.kube"
  }

  features = ["gateway-api", "longhorn", "prometheus", "spegel"]

  params_get = [
    local.accounts.locals.unifi.api_key_store,
    local.accounts.locals.github.token_store,
    local.accounts.locals.external_secrets.id_store,
    local.accounts.locals.external_secrets.secret_store,
    local.accounts.locals.healthchecksio.api_key_store,
  ]

  accounts_config = {
    unifi            = local.accounts.locals.unifi
    github           = local.accounts.locals.github
    external_secrets = local.accounts.locals.external_secrets
    healthchecksio   = local.accounts.locals.healthchecksio
  }
}

unit "aws_get_params" {
  source = "../../units/aws-get-params"
  path   = "aws-get-params"

  values = {
    names = local.params_get
  }
}

unit "config" {
  source = "../../units/config"
  path   = "config"

  values = {
    name                = local.cluster_name
    features            = local.features
    networking          = local.cluster_networking
    machines            = local.inventory.locals.hosts
    versions            = local.versions
    local_paths         = local.local_paths
    accounts            = local.accounts_config
    aws_get_params_path = "../aws-get-params"
  }
}
/*
unit "unifi" {
  source = "../../units/unifi"
  path   = "unifi"

  values = {
    config_path = "../config"
  }
}

unit "talos" {
  source = "../../units/talos"
  path   = "talos"

  values = {
    config_path = "../config"
  }
}

unit "bootstrap" {
  source = "../../units/bootstrap"
  path   = "bootstrap"

  values = {
    config_path = "../config"
    talos_path  = "../talos"
  }
}

unit "aws_set_params" {
  source = "../../units/aws-set-params"
  path   = "aws-set-params"

  values = {
    config_path = "../config"
    talos_path  = "../talos"
  }
}
*/
