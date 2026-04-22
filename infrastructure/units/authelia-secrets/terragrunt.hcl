include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../.././/modules/app-secrets"
}

inputs = {
  name = "authelia"

  secrets = {
    STORAGE_ENCRYPTION_KEY = { length = 64, special = false }
    SESSION_ENCRYPTION_KEY = { length = 64, special = false }
    JWT_TOKEN              = { length = 64, special = false }
  }

  ssm_parameter_path = "/homelab/kubernetes/live/authelia-secrets"

  local_backup_path = pathexpand("~/.secrets/homelab/authelia-secrets.json")
}
