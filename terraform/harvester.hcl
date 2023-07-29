locals {
  vm_storage_class_name = "fast"
  data_storage_class_name = "slow"

  harvester_kubeconfig_path = "~/.kube/harvester"
  harvester_management_address = "https://192.168.10.2"
  harvester_cluster_name = "homelab"
}
