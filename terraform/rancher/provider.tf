data "aws_ssm_parameter" "unifi_password" {
  name = var.unifi_management_password_store
}

data "aws_ssm_parameter" "cloudflare_api_key" {
  name = var.cloudflare_api_key_store
}

data "aws_ssm_parameter" "github_token" {
  name = var.github_token_store
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

provider "harvester" {
  kubeconfig = var.harvester_kubeconfig_path
}

provider "rke" {
  log_file = "rke_debug.log"
}

provider "rancher2" {
  alias     = "bootstrap"
  api_url   = "https://${var.rancher_cluster_name}.${var.default_network_tld}"
  bootstrap = true
}

provider "rancher2" {
  api_url   = module.rancher.rancher_admin_url
  token_key = module.rancher.rancher_admin_token
  insecure  = false
}

provider "cloudflare" {
  email   = var.master_email
  api_key = data.aws_ssm_parameter.cloudflare_api_key.value
}

provider "helm" {
  kubernetes {
    host                   = module.cluster.api_server_url
    client_certificate     = module.cluster.cluster_client_cert
    client_key             = module.cluster.cluster_client_key
    cluster_ca_certificate = module.cluster.cluster_ca_certificate
  }
}

provider "kubectl" {
  alias                  = "rancher"
  host                   = module.cluster.api_server_url
  client_certificate     = module.cluster.cluster_client_cert
  client_key             = module.cluster.cluster_client_key
  cluster_ca_certificate = module.cluster.cluster_ca_certificate
}

provider "kubectl" {
  alias       = "harvester"
  config_path = var.harvester_kubeconfig_path
}

provider "github" {
  owner = var.github_user
  token = data.aws_ssm_parameter.github_token.value
}

provider "unifi" {
  api_url        = var.unifi_management_address
  password       = data.aws_ssm_parameter.unifi_password.value
  username       = var.unifi_management_username
  allow_insecure = true
}

provider "random" {
  # Configuration options
}

provider "kubernetes" {
  config_path = local_file.kubeconfig.filename
}

provider "flux" {
  kubernetes = {
    config_path = local_file.kubeconfig.filename
  }
  git = {
    url          = "${var.github_ssh_addr}"
    author_email = "flux@${var.default_network_tld}"
    author_name  = "flux"
    branch       = "main"
    ssh = {
      username    = "git"
      private_key = "${data.aws_ssm_parameter.flux_ssh_key.value}"
    }
  }
}

data "aws_ssm_parameter" "flux_ssh_key" {
  name = var.github_ssh_key_store
}

data "aws_ssm_parameter" "healthchecksio_api_key" {
  name = var.healthchecksio_api_key_store
}

provider "healthchecksio" {
  api_key = data.aws_ssm_parameter.healthchecksio_api_key.value
}
