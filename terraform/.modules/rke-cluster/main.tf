resource "rke_cluster" "this" {
  enable_cri_dockerd = true
  dynamic "nodes" {
    iterator = vm
    for_each = harvester_virtualmachine.nodes
    content {
      address = vm.value.network_interface[0].ip_address
      user    = "ubuntu"
      role    = ["controlplane", "worker", "etcd"]
      ssh_key = aws_ssm_parameter.vm_ssh_key.value
    }
  }
}
