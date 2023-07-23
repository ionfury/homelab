output "api_server_url" {
  value = rke_cluster.this.api_server_url
}

output "cluster_client_cert" {
  value = rke_cluster.this.client_cert
}

output "cluster_client_key" {
  value = rke_cluster.this.client_key
}

output "cluster_ca_certificate" {
  value = rke_cluster.this.ca_crt
}

output "kube_config_yaml" {
  value = rke_cluster.this.kube_config_yaml
}

output "vm_ssh_key" {
  value = tls_private_key.vm_key.private_key_pem
}

# Really should be getting some sort of LB IP out but this is all we got
output "cluster_ip_address" {
  value = harvester_virtualmachine.nodes[keys(harvester_virtualmachine.nodes)[0]].network_interface[0].ip_address
}

output "cluster_mac_address" {
  value = harvester_virtualmachine.nodes[keys(harvester_virtualmachine.nodes)[0]].network_interface[0].mac_address
}
