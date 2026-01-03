include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../.././/modules/config"
}

dependency "aws_get_params" {
  config_path = values.aws_get_params_path

  mock_outputs = {
    values = {}
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  name        = values.name
  features    = values.features
  networking  = values.networking
  machines    = values.machines
  versions    = values.versions
  local_paths = values.local_paths
  accounts    = values.accounts
  values      = dependency.aws_get_params.outputs.values
}
