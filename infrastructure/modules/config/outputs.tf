output "unifi" {
  description = "Unifi module configuration."
  value = {
    dns_records       = local.dns_records
    dhcp_reservations = local.dhcp_reservations
  }
  sensitive = true
}

output "talos" {
  description = "Talos module configuration."
  value = {
    talos_version          = var.versions.talos
    kubernetes_version     = var.versions.kubernetes
    talos_machines         = local.talos_machines
    on_destroy             = var.on_destroy
    talos_config_path      = var.local_paths.talos
    kubernetes_config_path = var.local_paths.kubernetes
    talos_timeout          = "10m"
    bootstrap_charts = [{
      repository = "https://helm.cilium.io/"
      chart      = "cilium"
      name       = "cilium"
      version    = var.versions.cilium
      namespace  = "kube-system"
      values     = local.cilium_values
    }]
  }
  sensitive = true
}

output "bootstrap" {
  description = "Bootstrap module configuration."
  value = {
    cluster_name      = var.name
    flux_version      = var.versions.flux
    cluster_vars      = local.cluster_vars
    version_vars      = local.version_vars
    oci_semver        = local.oci_semver
    oci_semver_filter = local.oci_semver_filter
  }
  sensitive = true
}

output "aws_set_params" {
  description = "AWS SSM paths for credential storage."
  value = {
    kubeconfig_path  = "${var.ssm_output_path}/${var.name}/kubeconfig"
    talosconfig_path = "${var.ssm_output_path}/${var.name}/talosconfig"
  }
}

output "cluster_name" {
  description = "Cluster name."
  value       = var.name
}

output "cluster_endpoint" {
  description = "Cluster API endpoint hostname."
  value       = local.cluster_endpoint
}

output "machines" {
  description = "Transformed machines configuration."
  value       = local.machines
}

output "cluster_vars" {
  description = "Non-version flux post-build substitution variables."
  value       = local.cluster_vars
}

output "version_vars" {
  description = "Version flux post-build substitution variables."
  value       = local.version_vars
}
