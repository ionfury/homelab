output "params_get" {
  description = "SSM parameter names to fetch."
  value       = local.params_get
}

output "unifi" {
  description = "Unifi module configuration."
  value = {
    dns_records       = local.dns_records
    dhcp_reservations = local.dhcp_reservations
    address           = var.accounts.unifi.address
    site              = var.accounts.unifi.site
    api_key           = try(var.values[var.accounts.unifi.api_key_store], "")
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
  }
  sensitive = true
}

output "bootstrap" {
  description = "Bootstrap module configuration."
  value = {
    cluster_name     = var.name
    flux_version     = var.versions.flux
    cluster_env_vars = local.cluster_env_vars
    github = {
      org             = var.accounts.github.org
      repository      = var.accounts.github.repository
      repository_path = var.accounts.github.repository_path
      token           = try(var.values[var.accounts.github.token_store], "")
    }
    external_secrets = {
      id     = try(var.values[var.accounts.external_secrets.id_store], "")
      secret = try(var.values[var.accounts.external_secrets.secret_store], "")
    }
    healthchecksio = {
      api_key = try(var.values[var.accounts.healthchecksio.api_key_store], "")
    }
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

output "cluster_env_vars" {
  description = "Flux post-build substitution variables."
  value       = local.cluster_env_vars
}
