data "aws_ssm_parameter" "rancher_admin_url" {
  name = "rancher-admin-url"
}

data "aws_ssm_parameter" "rancher_admin_token" {
  name = "rancher-admin-token"
}

data "aws_ssm_parameter" "flux_ssh_key" {
  name = var.github_ssh_key_store
}

data "aws_ssm_parameter" "healthchecksio_api_key" {
  name = var.healthchecksio_api_key_store
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

provider "harvester" {
  kubeconfig = "~/.kube/harvester"
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

provider "healthchecksio" {
  api_key = data.aws_ssm_parameter.healthchecksio_api_key.value
}
