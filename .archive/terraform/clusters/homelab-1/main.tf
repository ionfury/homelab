moved {
  from = module.this.rancher2_machine_config_v2.control_plane
  to   = module.this.rancher2_machine_config_v2.machines["control-plane"]
}

moved {
  from = module.this.rancher2_machine_config_v2.worker
  to   = module.this.rancher2_machine_config_v2.machines["worker"]
}

module "this" {
  source = "../../.modules/rancher-harvester-cluster"

  restore = var.restore

  name                   = var.cluster_name
  harvester_cluster_name = var.harvester.cluster_name
  network_name           = var.harvester.network_name
  kubernetes_version     = var.kubernetes_version

  machine_pools = var.machine_pools

  rancher_admin_token = data.aws_ssm_parameter.rancher_admin_token.value
  rancher_admin_url   = data.aws_ssm_parameter.rancher_admin_url.value

  node_base_image = var.node_base_image

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
  user = var.external_secrets_access_key_store
}

data "aws_ssm_parameter" "github_ssh_key" {
  name = var.github.ssh_key_store
}

module "bootstrap" {
  source = "../../.modules/bootstrap-cluster"

  cluster_name = var.cluster_name

  github_ssh_pub = var.github.ssh_pub
  github_ssh_key = data.aws_ssm_parameter.github_ssh_key.value
  known_hosts    = var.github.ssh_known_hosts

  external_secrets_access_key_id     = aws_iam_access_key.external_secrets_access_key.id
  external_secrets_access_key_secret = aws_iam_access_key.external_secrets_access_key.secret

  providers = {
    flux           = flux
    healthchecksio = healthchecksio
  }
}

module "tunnel" {
  source = "../../.modules/tunnel"

  name                    = var.cluster_name
  cloudflare_account_name = var.cloudflare.account_name
  tld                     = var.tld

  providers = {
    cloudflare = cloudflare
  }
}
