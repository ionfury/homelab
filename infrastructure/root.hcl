locals {
  accounts_vars = read_terragrunt_config(find_in_parent_folders("accounts.hcl"))
}

inputs = merge(
  local.accounts_vars.locals,
)

catalog {
  urls = [
    "https://github.com/ionfury/homelab-modules"
  ]
}

remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = {
    bucket         = "homelab-terragrunt-remote-state"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "us-east-2"
    encrypt        = true
    dynamodb_table = "terragrunt"
  }
}
