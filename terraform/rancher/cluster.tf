module "cluster" {
  source                 = "../.modules/rke-cluster"
  name                   = var.rancher.cluster_name
  harvester_ssh_key_name = var.rancher.ssh_key_name
  kubernetes_version     = var.rancher.kubernetes_version
  harvester_network_name = var.harvester.network_name

  nodes_count = var.rancher.node_count
  node_cpu    = var.rancher.node_cpu
  node_memory = var.rancher.node_memory

  tags = {
    managed-by-terraform = true
  }

  providers = {
    harvester = harvester
    rke       = rke
    tls       = tls
  }
}

resource "random_string" "random" {
  length  = 6
  special = false
}

resource "local_file" "kubeconfig" {
  content  = module.cluster.kube_config_yaml
  filename = pathexpand("~/.kube/${var.rancher.cluster_name}-${random_string.random.result}")

  file_permission = "0644"
}

data "unifi_network" "this" {
  name = var.harvester.network_name
}

resource "unifi_user" "this" {
  mac  = module.cluster.cluster_mac_address
  name = var.rancher.cluster_name

  allow_existing   = true
  network_id       = data.unifi_network.this.id
  fixed_ip         = module.cluster.cluster_ip_address
  local_dns_record = join(".", [var.rancher.cluster_name, var.tld])
}

resource "aws_ssm_parameter" "vm_ssh_key" {
  name        = "${var.rancher.cluster_name}-node-ssh-key"
  description = "SSH key for accessing nodes belonging to ${var.rancher.cluster_name} RKE cluster."
  type        = "SecureString"
  value       = module.cluster.vm_ssh_key
  tags = {
    managed-by-terraform = "true"
  }
}

resource "aws_iam_user" "external_secrets_user" {
  name = "k8s-external-secrets-${var.rancher.cluster_name}"

  tags = {
    assignable-by-terragrunt = "true"
  }
}

data "aws_iam_policy" "external_secrets_policy" {
  name = "ssm-k8s-reader"
}

resource "aws_iam_user_policy_attachment" "external_secrets_policy_attachment" {
  user       = aws_iam_user.external_secrets_user.name
  policy_arn = data.aws_iam_policy.external_secrets_policy.arn
}

resource "aws_iam_access_key" "external_secrets_access_key" {
  user = aws_iam_user.external_secrets_user.name
}

data "aws_ssm_parameter" "github_ssh_key" {
  name = var.github.ssh_key_store
}

module "bootstrap" {
  source = "../.modules/bootstrap-cluster"

  cluster_name = var.rancher.cluster_name

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
