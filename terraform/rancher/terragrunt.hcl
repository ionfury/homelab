dependencies {
  paths = ["../harvester"]
}

include "root" {
  path = find_in_parent_folders()
}

inputs = {
  rancher_cluster_name = "rancher"
  rancher_ssh_key_name = "id-rsa-homelab-ssh-mac"
  rancher_node_count = 1 # No Load balancing capability, no reason for HA here
  rancher_version = "2.7.5"
  cert_manager_version = "1.12.0"
  kubernetes_version = "v1.26.4-rancher2-1"
}
