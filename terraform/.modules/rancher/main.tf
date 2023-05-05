provider "rancher2" {
  api_url = rancher2_bootstrap.admin.url
  token_key = rancher2_bootstrap.admin.token
  insecure = false
}

data "github_user" "ionfury" {
  username = "ionfury"
}

resource "rancher2_auth_config_github" "github" {
  client_id = var.github_oauth_client_id
  client_secret = var.github_oauth_client_secret
  access_mode = "restricted"
  allowed_principal_ids = [
    "github_user://${data.github_user.ionfury.id}",
  ]
}

data "rancher2_user" "ionfury" {
    name = "ionfury"
}

resource "rancher2_global_role_binding" "foo" {
  name = "ionfury-admin-binding"
  global_role_id = "admin"
  user_id = data.rancher2_user.ionfury.id
}

