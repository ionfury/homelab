provider "aws" {
  region  = var.aws.region
  profile = var.aws.profile
}

provider "harvester" {
  kubeconfig = var.harvester.kubeconfig_path
}

provider "kubectl" {
  config_path = var.harvester.kubeconfig_path
}

provider "kubernetes" {
  config_path = var.harvester.kubeconfig_path
}

provider "flux" {
  kubernetes = {
    config_path = var.harvester.kubeconfig_path
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
