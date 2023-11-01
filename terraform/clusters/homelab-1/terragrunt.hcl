include "root" {
  path = find_in_parent_folders()
}

dependencies {
  paths = ["../../rancher"]
}

inputs = {
  cluster_name = "${basename(get_terragrunt_dir())}"
  kubernetes_version = "v1.26.8+rke2r1"
}
