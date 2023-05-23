locals {
  cluster_name = "cluster-01"
}

provider "rancher2" {
  api_url   = data.aws_ssm_parameter.rancher_admin_url.value
  token_key = data.aws_ssm_parameter.rancher_admin_token.value
  insecure  = false
}

data "aws_ssm_parameter" "rancher_admin_url" {
  name = "rancher-admin-url"
}

data "aws_ssm_parameter" "rancher_admin_token" {
  name = "rancher-admin-token"
}

data "aws_ssm_parameter" "flux_ssh_key" {
  name = "terraform-flux-key"
}

data "harvester_network" "kubernetes" {
  name = "kubernetes"
}

resource "aws_iam_access_key" "external_secrets_access_key" {
  user = "k8s-external-secrets"
}

module "cluster_01" {
  source       = "../.modules/rancher-rke2-cluster"
  name         = "cluster-01"
  network_name = data.harvester_network.kubernetes.name

  github_url     = "ssh://git@github.com/ionfury/homelab.git"
  github_ssh_key = data.aws_ssm_parameter.flux_ssh_key.value
  github_ssh_pub = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMCrYcFCCCpSN4EhzZ7vtjIsOx3P7DTb8KKwhDPXxZfs flux@tomnowak.work"

  access_key_id     = aws_iam_access_key.external_secrets_access_key.id
  access_key_secret = aws_iam_access_key.external_secrets_access_key.secret

  rancher_admin_token = data.aws_ssm_parameter.rancher_admin_token.value
  rancher_admin_url   = data.aws_ssm_parameter.rancher_admin_url.value


  worker_cpu        = 8
  worker_memory     = 32
  worker_node_count = 3

  providers = {
    rancher2       = rancher2
    aws            = aws
    healthchecksio = healthchecksio
  }
}
