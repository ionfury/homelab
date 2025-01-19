
data "rancher2_user" "owner" {
  provider    = rancher2.admin
  name        = var.github.name
  is_external = true
}

data "aws_ssm_parameter" "github_oauth_secret" {
  name = var.github.oauth_secret_store
}

data "aws_ssm_parameter" "github_oauth_clientid" {
  name = var.github.oauth_clientid_store
}

data "github_user" "this" {
  username = var.github.user
}

resource "rancher2_global_role_binding" "owner" {
  provider       = rancher2.admin
  name           = "admin-binding"
  global_role_id = "admin"
  user_id        = data.rancher2_user.owner.id
}

resource "rancher2_auth_config_github" "github" {
  provider      = rancher2.admin
  client_id     = data.aws_ssm_parameter.github_oauth_clientid.value
  client_secret = data.aws_ssm_parameter.github_oauth_secret.value
  access_mode   = "restricted"
  allowed_principal_ids = [
    "github_user://${data.github_user.this.id}",
  ]
}
