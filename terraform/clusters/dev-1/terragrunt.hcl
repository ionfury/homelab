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
    nodes = 1
    cpu = 2
    memory = 8
    disk = 60
  }

  worker = {
    nodes = 1
    cpu = 2
    memory = 8
    disk = 60
  }

  image_name = "${basename(get_terragrunt_dir())}-ubuntu-2004-latest"
  image = "http://cloud-images.ubuntu.com/releases/focal/release/ubuntu-20.04-server-cloudimg-amd64.img"
  image_ssh_user = "ubuntu"
}
