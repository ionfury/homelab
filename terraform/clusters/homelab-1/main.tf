module "this" {
  source = "../../.modules/rancher-harvester-cluster"

  name                   = var.cluster_name
  harvester_cluster_name = var.harvester_cluster_name
  network_name           = var.default_network_name
  kubernetes_version     = var.kubernetes_version

  control_plane_cpu        = 2
  control_plane_memory     = 8
  control_plane_disk       = 60
  control_plane_node_count = 3

  worker_cpu        = 8
  worker_memory     = 64
  worker_disk       = 100
  worker_node_count = 3

  rancher_admin_token = data.aws_ssm_parameter.rancher_admin_token.value
  rancher_admin_url   = data.aws_ssm_parameter.rancher_admin_url.value

  providers = {
    rancher2  = rancher2
    harvester = harvester
    aws       = aws
  }
}

resource "random_string" "random" {
  length  = 6
  special = false
}

resource "local_file" "kubeconfig" {
  content  = module.this.kube_config
  filename = pathexpand("~/.kube/${var.cluster_name}-${random_string.random.result}")

  file_permission = "0644"
}

resource "aws_iam_access_key" "external_secrets_access_key" {
  user = var.external_secrets_access_key_name
}

data "aws_ssm_parameter" "github_ssh_key" {
  name = var.github_ssh_key_store
}

module "bootstrap" {
  source = "../../.modules/bootstrap-cluster"

  cluster_name = var.cluster_name

  github_ssh_pub = var.github_ssh_pub
  github_ssh_key = data.aws_ssm_parameter.github_ssh_key.value
  known_hosts    = var.github_ssh_known_hosts

  external_secrets_access_key_id     = aws_iam_access_key.external_secrets_access_key.id
  external_secrets_access_key_secret = aws_iam_access_key.external_secrets_access_key.secret

  providers = {
    flux           = flux
    healthchecksio = healthchecksio
  }
}
