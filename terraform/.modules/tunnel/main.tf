data "cloudflare_zone" "domain" {
  name = var.tld
}

resource "random_password" "this" {
  length  = 24
  special = false
}

data "cloudflare_accounts" "this" {
  name = var.cloudflare_account_name
}

resource "cloudflare_tunnel" "this" {
  account_id = data.cloudflare_accounts.this.accounts[0].id
  name       = var.name
  secret     = random_password.this.result
}

resource "aws_ssm_parameter" "token" {
  name        = "k8s-${var.name}-cloudflare-tunnel"
  description = "Cloudflare tunnel for cluster: ${var.name}."
  type        = "SecureString"
  value       = jsonencode({ "id" = "${cloudflare_tunnel.this.id}", "token" = "${cloudflare_tunnel.this.tunnel_token}", "secret" = "${cloudflare_tunnel.this.secret}", "account" = "${cloudflare_tunnel.this.account_id}" })
}

resource "cloudflare_record" "this" {
  name    = "${var.name}.${var.tld}"
  zone_id = data.cloudflare_zone.domain.id
  value   = cloudflare_tunnel.this.cname
  proxied = true
  type    = "CNAME"
  ttl     = 1
}
