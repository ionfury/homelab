include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "common" {
  path   = "${dirname(find_in_parent_folders("root.hcl"))}/_common/params-get.hcl"
  expose = true
}

terraform {
  source = "${include.common.locals.base_source_url}?ref=v0.18.0"
}
