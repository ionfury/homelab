terraform_version_constraint  = ">= 1.5.0"
terragrunt_version_constraint = ">= 0.47.0"

locals {
  global_vars = read_terragrunt_config(find_in_parent_folders("global.hcl"))
  external_vars = read_terragrunt_config(find_in_parent_folders("external.hcl"))
  infrastructure_vars = read_terragrunt_config(find_in_parent_folders("infrastructure.hcl"))
}

inputs = merge(
  local.global_vars.locals,
  local.external_vars.locals,
  local.infrastructure_vars.locals
)

remote_state {
  backend = "s3"
  generate = {
    path = "backend.tf"
    if_exists = "overwrite"
  }
  config = {
    bucket = "homelab-terragrunt-remote-state"
    key = "${path_relative_to_include()}/terraform.tfstate"
    region = "us-east-2"
    encrypt = true
    dynamodb_table = "terragrunt"
    profile = "terragrunt"
  }
}
