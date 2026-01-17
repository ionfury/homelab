include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../.././/modules/longhorn-storage"
}

inputs = {
  clusters = values.clusters
  region   = "us-east-2"
}
