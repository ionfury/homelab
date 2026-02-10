include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../.././/modules/app-secrets"
}

inputs = {
  name = "lldap"

  secrets = {
    LLDAP_JWT_SECRET     = { length = 32, special = false }
    LLDAP_LDAP_USER_PASS = { length = 32, special = false }
    LLDAP_KEY_SEED       = { length = 32, special = false }
  }

  ssm_parameter_path = "/homelab/kubernetes/live/lldap-secrets"

  local_backup_path = pathexpand("~/.secrets/homelab/lldap-secrets.json")
}
