include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../.././/modules/velero-storage"
}

inputs = {
  clusters = values.clusters
  region   = "us-east-2"
}
