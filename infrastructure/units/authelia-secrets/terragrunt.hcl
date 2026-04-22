include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../.././/modules/app-secrets"
}

inputs = {
  name = "authelia"

  secrets = {
    storage_encryption_key = { length = 64, special = false }
    session_encryption_key = { length = 64, special = false }
    jwt_hmac_key           = { length = 64, special = false }
    oidc_hmac_key          = { length = 64, special = false }
  }

  ssm_parameter_path = "/homelab/kubernetes/live/authelia-secrets"

  local_backup_path = pathexpand("~/.secrets/homelab/authelia-secrets.json")
}
