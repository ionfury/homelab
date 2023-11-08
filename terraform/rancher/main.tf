resource "aws_ssm_parameter" "rancher_admin_url" {
  name        = "rancher-admin-url"
  description = "Rancher server url in my homelab."
  type        = "String"
  value       = module.rancher.rancher_admin_url
  tags = {
    managed-by-terraform = "true"
  }
}

resource "aws_ssm_parameter" "rancher_admin_token" {
  name        = "rancher-admin-token"
  description = "Rancher admin token in my homelab."
  type        = "SecureString"
  value       = module.rancher.rancher_admin_token
  tags = {
    managed-by-terraform = "true"
  }
}

module "rancher" {
  source     = "../.modules/rancher"
  depends_on = [module.cluster, unifi_user.this]

  cert_manager_version = var.rancher.cert_manager_version
  rancher_version      = var.rancher.rancher_version
  network_subdomain    = var.rancher.cluster_name
  network_tld          = var.tld
  letsencrypt_issuer   = var.github.email

  providers = {
    cloudflare = cloudflare
    rancher2   = rancher2.bootstrap
    kubectl    = kubectl.rancher
    helm       = helm
  }
}
