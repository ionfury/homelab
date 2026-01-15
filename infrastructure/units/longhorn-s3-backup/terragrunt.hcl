include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../.././/modules/longhorn-s3-backup"
}

dependency "config" {
  config_path = "../config"

  mock_outputs = {
    cluster_name = "mock"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  cluster_name   = dependency.config.outputs.cluster_name
  region         = "us-east-2"
  retention_days = 90
}
