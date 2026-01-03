resource "local_sensitive_file" "machineconf" {
  for_each = data.talos_machine_configuration.this

  content         = each.value.machine_configuration
  filename        = pathexpand("${var.talos_config_path}/${local.cluster_name}-${each.key}-machine_configuration.yaml")
  file_permission = "0644"
}

output "machineconf_filenames" {
  description = "The filenames of the generated Talos machine configuration files."
  value       = [for f in local_sensitive_file.machineconf : f.filename]
}

resource "local_sensitive_file" "talosconfig" {
  content         = data.talos_client_configuration.this.talos_config
  filename        = pathexpand("${var.talos_config_path}/${local.cluster_name}.yaml")
  file_permission = "0644"
}

output "talosconfig_filename" {
  description = "The filename of the generated Talos client configuration file."
  value       = local_sensitive_file.talosconfig.filename
}

output "talosconfig_raw" {
  description = "The raw Talos client configuration."
  sensitive   = true
  value       = data.talos_client_configuration.this.talos_config
}

resource "local_sensitive_file" "kubeconfig" {
  content         = talos_cluster_kubeconfig.this.kubeconfig_raw
  filename        = pathexpand("${var.kubernetes_config_path}/${local.cluster_name}.yaml")
  file_permission = "0644"
}

output "kubeconfig_filename" {
  description = "The filename of the generated Kubernetes kubeconfig file."
  value       = local_sensitive_file.kubeconfig.filename
}

output "kubeconfig_raw" {
  description = "The raw Kubernetes kubeconfig."
  sensitive   = true
  value       = talos_cluster_kubeconfig.this.kubeconfig_raw
}

output "kubeconfig_host" {
  description = "The host from the kubeconfig."
  sensitive   = true
  value       = talos_cluster_kubeconfig.this.kubernetes_client_configuration.host
}

output "kubeconfig_client_certificate" {
  description = "The client certificate from the kubeconfig."
  sensitive   = true
  value       = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_certificate)
}

output "kubeconfig_client_key" {
  description = "The client key from the kubeconfig."
  sensitive   = true
  value       = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_key)
}

output "kubeconfig_cluster_ca_certificate" {
  description = "The cluster CA certificate from the kubeconfig."
  sensitive   = true
  value       = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.ca_certificate)
}
