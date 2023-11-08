data "aws_ssm_parameter" "unifi_password" {
  name = var.unifi.password_store
}

data "aws_ssm_parameter" "cloudflare_api_key" {
  name = var.cloudflare.api_key_store
}

data "aws_ssm_parameter" "github_token" {
  name = var.github.token_store
}

provider "aws" {
  region  = var.aws.region
  profile = var.aws.profile
}

provider "harvester" {
  kubeconfig = var.harvester.kubeconfig_path
}

provider "rke" {
  log_file = "rke_debug.log"
}

provider "rancher2" {
  alias     = "bootstrap"
  api_url   = "https://${var.rancher.cluster_name}.${var.tld}"
  bootstrap = true
}

provider "rancher2" {
  alias     = "admin"
  api_url   = module.rancher.rancher_admin_url
  token_key = module.rancher.rancher_admin_token
  insecure  = false
}

provider "cloudflare" {
  email   = var.cloudflare.email
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
  config_path = var.harvester.kubeconfig_path
}

provider "github" {
  owner = var.github.user
  token = data.aws_ssm_parameter.github_token.value
}

provider "unifi" {
  api_url        = var.unifi.address
  password       = data.aws_ssm_parameter.unifi_password.value
  username       = var.unifi.username
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
    url          = "${var.github.ssh_addr}"
    author_email = "flux@${var.tld}"
    author_name  = "flux"
    branch       = "main"
    ssh = {
      username    = "git"
      private_key = "${data.aws_ssm_parameter.flux_ssh_key.value}"
    }
  }
}

data "aws_ssm_parameter" "flux_ssh_key" {
  name = var.github.ssh_key_store
}

data "aws_ssm_parameter" "healthchecksio_api_key" {
  name = var.healthchecksio.api_key_store
}

provider "healthchecksio" {
  api_key = data.aws_ssm_parameter.healthchecksio_api_key.value
}
