include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../.././/modules/aws-get-params"
}

inputs = {
  names = values.names
}
