data "aws_ssm_parameter" "github_oauth_secret" {
  name = var.github_oauth_secret_store
}

data "aws_ssm_parameter" "github_oauth_clientid" {
  name = var.github_oauth_clientid_store
}

data "github_user" "this" {
  username = var.github.user
}

module "rancher" {
  source     = "../.modules/rancher"
  depends_on = [module.cluster, unifi_user.this]

  cert_manager_version = var.rancher.cert_manager_version
  rancher_version      = var.rancher.rancher_version
  network_subdomain    = var.rancher.cluster_name
  network_tld          = var.tld
  letsencrypt_issuer   = var.master_email

  github_oauth_client_id     = data.aws_ssm_parameter.github_oauth_clientid.value
  github_oauth_client_secret = data.aws_ssm_parameter.github_oauth_secret.value
  github_user_id             = data.github_user.this.id
  github_user                = var.github.name

  providers = {
    cloudflare = cloudflare
    rancher2   = rancher2.bootstrap
    kubectl    = kubectl.rancher
    helm       = helm
  }
}

data "rancher2_user" "owner" {
  depends_on  = [module.rancher]
  name        = var.github.name
  is_external = true
}

resource "rancher2_global_role_binding" "owner" {
  name           = "admin-binding"
  global_role_id = "admin"
  user_id        = data.rancher2_user.owner.id
}

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
