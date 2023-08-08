module "cluster" {
  source                 = "../.modules/rke-cluster"
  name                   = var.rancher_cluster_name
  nodes_count            = var.rancher_node_count
  harvester_ssh_key_name = var.rancher_ssh_key_name
  harvester_network_name = var.default_network_name
  kubernetes_version     = var.kubernetes_version

  node_memory = "16Gi"

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
  filename = pathexpand("~/.kube/${var.rancher_cluster_name}-${random_string.random.result}")

  file_permission = "0644"
}

data "unifi_network" "this" {
  name = var.default_network_name
}

resource "unifi_user" "this" {
  mac  = module.cluster.cluster_mac_address
  name = var.rancher_cluster_name

  allow_existing   = true
  network_id       = data.unifi_network.this.id
  fixed_ip         = module.cluster.cluster_ip_address
  local_dns_record = join(".", [var.rancher_cluster_name, var.default_network_tld])
}

resource "aws_ssm_parameter" "vm_ssh_key" {
  name        = "${var.rancher_cluster_name}-node-ssh-key"
  description = "SSH key for accessing nodes belonging to ${var.rancher_cluster_name} RKE cluster."
  type        = "SecureString"
  value       = module.cluster.vm_ssh_key
  tags = {
    managed-by-terraform = "true"
  }
}

resource "aws_iam_access_key" "external_secrets_access_key" {
  user = var.external_secrets_access_key_name
}

data "aws_ssm_parameter" "github_ssh_key" {
  name = var.github_ssh_key_store
}

module "bootstrap" {
  source = "../.modules/bootstrap-cluster"

  cluster_name = var.rancher_cluster_name

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
