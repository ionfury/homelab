include "root" {
  path = find_in_parent_folders()
}

dependencies {
  paths = ["../../rancher"]
}

inputs = {
  cluster_name = "${basename(get_terragrunt_dir())}"
  kubernetes_version = "v1.26.13+rke2r1"

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
        worker = false
      }
      gpu_enabled = false
      machine_labels = {}
      vm_affinity_b64 = ""
    }
    worker = {
      min_size = 2
      max_size = 5
      node_startup_timeout_seconds = 1200
      unhealthy_node_timeout_seconds = 240
      max_unhealthy = "1"
      resources = {
        cpu = 8
        memory = 32
        disk = 80
      }
      roles = {
        control_plane = false
        etcd = false
        worker = true
      }
      gpu_enabled = false
      machine_labels = {}
      vm_affinity_b64 = ""
    }
    gpu = {
      min_size = 1
      max_size = 1
      node_startup_timeout_seconds = 1200
      unhealthy_node_timeout_seconds = 600
      max_unhealthy = "1"
      resources = {
        cpu = 16
        memory = 64
        disk = 120
      }
      roles = {
        control_plane = false
        etcd = false
        worker = true
      }
      gpu_enabled = true
      machine_labels = {
        "gpu-required" = "true"
      }
      # {"nodeAffinity":{"requiredDuringSchedulingIgnoredDuringExecution":{"nodeSelectorTerms":[{"matchExpressions":[{"key":"gpu","operator":"In","values":["true"]}]}]}}}
      vm_affinity_b64 = "eyJub2RlQWZmaW5pdHkiOnsicmVxdWlyZWREdXJpbmdTY2hlZHVsaW5nSWdub3JlZER1cmluZ0V4ZWN1dGlvbiI6eyJub2RlU2VsZWN0b3JUZXJtcyI6W3sibWF0Y2hFeHByZXNzaW9ucyI6W3sia2V5IjoiZ3B1Iiwib3BlcmF0b3IiOiJJbiIsInZhbHVlcyI6WyJ0cnVlIl19XX1dfX19"
    }
  }

  image_name = "${basename(get_terragrunt_dir())}-ubuntu-2004-latest"
  image = "http://cloud-images.ubuntu.com/releases/focal/release/ubuntu-20.04-server-cloudimg-amd64.img"
  image_ssh_user = "ubuntu"
}
