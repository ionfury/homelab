// Generic Outputs for the cluster configuration

output "cluster_name" {
  description = "The name of the cluster."
  value       = ""
}

// Unifi specific outputs

output "dns_records" {
  description = "The DNS records created in Unifi."
  value       = ""
}

output "dhcp_reservations" {
  description = "The DHCP reservations created in Unifi."
  value       = ""
}

output "unifi_api_key" {
  description = "The Unifi API key used."
  value       = ""
}

// Talos specific outputs

output "talos_version" {
  description = "The Talos version."
  value       = var.versions.talos
}

output "kubernetes_version" {
  description = "The Kubernetes version."
  value       = var.versions.kubernetes
}

output "talos_machines" {
  description = "The Talos machines."
  value       = ""
}

output "on_destroy" {
  description = "The on_destroy settings."
  value       = ""
}

output "talos_config_path" {
  description = "The path to the Talos config."
  value       = var.local_paths.talos
}

output "kubernetes_config_path" {
  description = "The path to the Kubernetes config."
  value       = var.local_paths.kubernetes
}

output "talos_timeout" {
  description = "The Talos timeout settings."
  value       = "10m"
}

// Bootstrap specific outputs

output "flux_version" {
  description = "The Flux version."
  value       = var.versions.flux
}

output "cluster_env_vars" {
  description = "Environment variables to add to the cluster git repository root directory."
  value       = ""
}

output "healthchecksio_replication_allowed_namespaces" {
  description = "Namespaces to allow replication for healthchecks.io."
  value       = ""
}

output "unifi_api_key" {
  description = "The Unifi API key."
  value       = ""
}

output "github_token" {
  description = "The GitHub token."
  value       = ""
}

output "external_secrets_id" {
  description = "The external secrets ID."
  value       = ""
}

output "healthchecksio_api_key" {
  description = "The healthchecks.io API key."
  value       = ""
}
