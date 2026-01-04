locals {
  accounts_vars = read_terragrunt_config(find_in_parent_folders("accounts.hcl"))
  accounts      = local.accounts_vars.locals.accounts

  params = [
    local.accounts.unifi.api_key_store,
    local.accounts.github.token_store,
    local.accounts.external_secrets.id_store,
    local.accounts.external_secrets.secret_store,
    local.accounts.healthchecksio.api_key_store,
  ]
}

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../.././/modules/aws-get-params"
}

inputs = {
  names = local.params
}
