provider "rancher2" {
  alias = "bootstrap"
  api_url   = "https://${var.rancher_domain_prefix}.${var.cloudflare_domain}"
  bootstrap = true
}

resource "rancher2_bootstrap" "admin" {
  provider = rancher2.bootstrap
  initial_password = random_password.rancher_bootstrap_password.result
  password = random_password.rancher_bootstrap_password.result
  telemetry = false
  depends_on = [helm_release.rancher]
}

resource "aws_ssm_parameter" "rancher_admin_url" {
  name = "rancher-admin-url"
  description = "Rancher server url in my homelab."
  type = "String"
  value = rancher2_bootstrap.admin.url
  tags = {
    managed-by-terraform = "true"
  }
}

resource "aws_ssm_parameter" "rancher_admin_token" {
  name = "rancher-admin-token"
  description = "Rancher admin token in my homelab."
  type = "SecureString"
  value = rancher2_bootstrap.admin.token
  tags = {
    managed-by-terraform = "true"
  }
}
