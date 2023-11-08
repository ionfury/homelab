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
