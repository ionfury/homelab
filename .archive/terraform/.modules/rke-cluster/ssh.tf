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
