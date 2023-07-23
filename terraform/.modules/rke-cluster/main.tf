resource "rke_cluster" "this" {
  enable_cri_dockerd = true
  kubernetes_version = var.kubernetes_version
  dynamic "nodes" {
    iterator = vm
    for_each = harvester_virtualmachine.nodes
    content {
      address = vm.value.network_interface[0].ip_address
      user    = "ubuntu"
      role    = ["controlplane", "worker", "etcd"]
      ssh_key = tls_private_key.vm_key.private_key_pem
    }
  }
}
