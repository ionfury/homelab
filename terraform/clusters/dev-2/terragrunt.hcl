include "root" {
  path = find_in_parent_folders()
}

dependencies {
  paths = ["../../rancher"]
}

inputs = {
  cluster_name = "${basename(get_terragrunt_dir())}"
  kubernetes_version = "v1.26.13+rke2r1"
  node_base_image_version = "next"
  node_base_image = {
    this = {
      name = "${basename(get_terragrunt_dir())}-ubuntu-2004-latest"
      namespace = "default"
      url = "http://cloud-images.ubuntu.com/releases/focal/release/ubuntu-20.04-server-cloudimg-amd64.img"
      ssh_user = "ubuntu"
    }
    next = {
      name = "${basename(get_terragrunt_dir())}-ubuntu-2204-20240614"
      namespace = "default"
      url = "https://cloud-images.ubuntu.com/releases/jammy/release-20240614/ubuntu-22.04-server-cloudimg-amd64.img"
      ssh_user = "ubuntu"
    }
  }

  machine_pools = {
    control-plane = {
      min_size = 3
      max_size = 3
      node_startup_timeout_seconds = 1200
      unhealthy_node_timeout_seconds = 240
      max_unhealthy = "1"
      resources = {
        cpu = 2
        memory = 8
        disk = 60
      }
      roles = {
        control_plane = true
        etcd = true
        worker = true
      }
      gpu_enabled = false
      machine_labels = {}
      vm_affinity_b64 = ""
    }
  }
}
