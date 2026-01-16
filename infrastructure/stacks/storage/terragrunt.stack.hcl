# Storage stack - persistent infrastructure independent of cluster lifecycle
# Provisions Longhorn backup buckets for all clusters so backups survive cluster rebuilds.

locals {
  # All clusters that need Longhorn backup infrastructure
  clusters = ["dev", "integration", "live"]
}

unit "longhorn_storage" {
  source = "../../units/longhorn-storage"
  path   = "longhorn-storage"

  values = {
    clusters = local.clusters
  }
}
