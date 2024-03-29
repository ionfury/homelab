locals {
  node_name = "${var.name}-m"

  nodes = {
    for i in range(var.nodes_count) : "${local.node_name}-${i}" =>
    {
      hostname = "${local.node_name}-${i}"
    }
  }
}

data "harvester_network" "harvester" {
  name      = var.harvester_network_name
  namespace = var.namespace
}

resource "harvester_image" "this" {
  name         = "${var.name}-image"
  display_name = "${var.name}-image"
  namespace    = "default"
  source_type  = "download"
  url          = var.base_image
}

resource "harvester_virtualmachine" "nodes" {
  for_each = local.nodes
  name     = each.key
  hostname = each.value.hostname

  namespace   = var.namespace
  description = "${var.name} kubernetes node."

  restart_after_update = true
  cpu                  = var.node_cpu
  memory               = var.node_memory
  efi                  = true
  secure_boot          = true
  run_strategy         = "RerunOnFailure"
  machine_type         = "q35"

  ssh_keys = [
    data.harvester_ssh_key.key.id,
    harvester_ssh_key.vm_ssh_key.id
  ]

  network_interface {
    name           = "nic-1"
    network_name   = data.harvester_network.harvester.id
    wait_for_lease = true
  }

  disk {
    name       = "root"
    type       = "disk"
    size       = var.node_disk
    bus        = "virtio"
    boot_order = 1

    image       = harvester_image.this.id
    auto_delete = true
  }

  cloudinit {
    user_data = <<-EOF
      #cloud-config
      hostname: ${each.value.hostname}
      ssh_pwauth: true
      package_update: true
      packages:
        - qemu-guest-agent
        - docker.io
      # create the docker group
      groups:
        - docker
      # Add default auto created user to docker group
      system_info:
        default_user:
          groups: [docker]
      runcmd:
        - - systemctl
          - enable
          - '--now'
          - qemu-guest-agent
      ssh_authorized_keys:
        - ${data.harvester_ssh_key.key.public_key}
        - ${harvester_ssh_key.vm_ssh_key.public_key}
      EOF
  }

  tags = {
    "vm-set"             = "${var.name}"
    managed-by-terraform = true
  }
}
