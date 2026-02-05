include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../.././/modules/pki"
}

inputs = {
  ca_name = "homelab-ingress"

  ca_subject = {
    organization = "homelab"
    common_name  = "homelab-ingress-root-ca"
  }

  validity_days = 3650 # 10 years

  ssm_parameter_path = "/homelab/kubernetes/shared/homelab-ingress-ca"

  local_backup_path = pathexpand("~/.secrets/homelab/homelab-ingress-ca.json")
}
