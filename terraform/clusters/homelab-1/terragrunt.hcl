include "root" {
  path = find_in_parent_folders()
}

dependencies {
  paths = ["../../rancher"]
}

inputs = {
  cluster_name = "${basename(get_terragrunt_dir())}"
  kubernetes_version = "v1.26.8+rke2r1"

  control_plane = {
    nodes = 3
    cpu = 2
    memory = 8
    disk = 60
  }

  worker = {
    nodes = 3
    cpu = 8
    memory = 64
    disk = 100
  }
}
