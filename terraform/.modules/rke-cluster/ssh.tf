data "harvester_ssh_key" "key" {
  name      = var.harvester_ssh_key_name
  namespace = var.namespace
}

resource "tls_private_key" "vm_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "harvester_ssh_key" "vm_ssh_key" {
  name       = "${var.name}-vm-ssh-key"
  public_key = trimspace(tls_private_key.vm_key.public_key_openssh)

  tags = var.tags
}

resource "aws_ssm_parameter" "vm_ssh_key" {
  name        = "${var.name}-node-ssh-key"
  description = "SSH key for accessing nodes belonging to ${var.name} RKE cluster."
  type        = "SecureString"
  value       = tls_private_key.vm_key.private_key_pem
  tags = {
    managed-by-terraform = "true"
  }
}
