include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "common" {
  path   = "${dirname(find_in_parent_folders("root.hcl"))}/_common/talos-cluster.hcl"
  expose = true
}

terraform {
  source = "${include.common.locals.base_source_url}?ref=v0.10.0"
}

inputs = {
  cluster_name       = "testing"
  cluster_endpoint   = "192.168.10.246"
  talos_version      = "v1.9.1"
  kubernetes_version = "1.30.2"

  machines = {
    node46 = {
      type = "controlplane"
      install = {
        diskSelectors = ["type: 'ssd'"]
      }
      interfaces = [
        {
          hardwareAddr = "ac:1f:6b:2d:c0:22"
          addresses    = ["192.168.10.246"]
        }
      ]
    }
  }
}
