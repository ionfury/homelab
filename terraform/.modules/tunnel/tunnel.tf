resource "random_password" "this" {
  length  = 24
  special = false
}

data "cloudflare_accounts" "this" {
  name = var.cloudflare_account_name
}

resource "cloudflare_tunnel" "this" {
  account_id = data.cloudflare_accounts.this.id
  name       = var.name
  secret     = random_password.this.result
}

resource "aws_ssm_parameter" "token" {
  name        = "k8s-${var.name}-cloudflare-tunnel"
  description = "Cloudflare tunnel for cluster: ${var.name}."
  type        = "SecureString"
  value       = jsonencode({ "id" = "${cloudflare_tunnel.this.id}", "token" = "${cloudflare_tunnel.this.tunnel_token}" })
}
