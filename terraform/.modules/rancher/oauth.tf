resource "rancher2_auth_config_github" "github" {
  depends_on = [rancher2_bootstrap.admin]

  client_id     = var.github_oauth_client_id
  client_secret = var.github_oauth_client_secret
  access_mode   = "restricted"
  allowed_principal_ids = [
    "github_user://${var.github_user_id}",
  ]
}
