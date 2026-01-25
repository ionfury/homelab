include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../.././/modules/pki"
}

inputs = {
  ca_name = "istio-mesh"

  ca_subject = {
    organization = "homelab"
    common_name  = "istio-mesh-root-ca"
  }

  validity_days = 3650 # 10 years

  ssm_parameter_path = "/homelab/kubernetes/shared/istio-mesh-ca"

  local_backup_path = pathexpand("~/.secrets/homelab/istio-mesh-ca.json")
}
