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
