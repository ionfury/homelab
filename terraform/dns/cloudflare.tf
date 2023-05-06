
data "cloudflare_api_token_permission_groups" "all" {}

resource "cloudflare_api_token" "dns_write" {
  name = "dns-write"

  policy {
    permission_groups = [
      data.cloudflare_api_token_permission_groups.all.zone["DNS Write"],
      data.cloudflare_api_token_permission_groups.all.zone["DNS Read"],
      data.cloudflare_api_token_permission_groups.all.zone["Zone Read"],
    ]
    resources = {
      "com.cloudflare.api.account.zone.*" = "*"
    }
  }
}

# k8s: manifests/apps/issuers/cloudflare-issuer/external-secret.yaml
resource "aws_ssm_parameter" "k8s_dns_write" {
  name        = "k8s-dns-write"
  description = "Cloudflare api token to perform dns write actions"
  type        = "SecureString"
  value       = jsonencode({ "token" = "${cloudflare_api_token.dns_write.value}" })
}
