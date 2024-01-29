data "aws_ssm_parameter" "rancher_admin_url" {
  name = "rancher-admin-url"
}

data "aws_ssm_parameter" "rancher_admin_token" {
  name = "rancher-admin-token"
}

data "aws_ssm_parameter" "flux_ssh_key" {
  name = var.github.ssh_key_store
}

data "aws_ssm_parameter" "healthchecksio_api_key" {
  name = var.healthchecksio.api_key_store
}

provider "aws" {
  region  = var.aws.region
  profile = var.aws.profile
}

provider "harvester" {
  kubeconfig = var.harvester.kubeconfig_path
}

provider "rancher2" {
  api_url   = data.aws_ssm_parameter.rancher_admin_url.value
  token_key = data.aws_ssm_parameter.rancher_admin_token.value
  insecure  = false
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
    author_email = "flux@${var.default.network_tld}"
    author_name  = "flux"
    branch       = "main"
    ssh = {
      username    = "git"
      private_key = "${data.aws_ssm_parameter.flux_ssh_key.value}"
    }
  }
}

provider "healthchecksio" {
  api_key = data.aws_ssm_parameter.healthchecksio_api_key.value
}

data "aws_ssm_parameter" "cloudflare_api_key" {
  name = var.cloudflare.api_key_store
}

provider "cloudflare" {
  email   = var.cloudflare.email
  api_key = data.aws_ssm_parameter.cloudflare_api_key.value
}

provider "kubectl" {
  config_path = "~/.kube/rancher-tRf58g"
}
