# Global stack - cross-cluster infrastructure independent of individual cluster lifecycles
# Provisions resources shared across all clusters: S3 backup buckets, PKI certificates.

locals {
  # All clusters that need shared infrastructure
  clusters = ["dev", "integration", "live"]
}

unit "longhorn_storage" {
  source = "../../units/longhorn-storage"
  path   = "longhorn-storage"

  values = {
    clusters = local.clusters
  }
}

unit "pki" {
  source = "../../units/pki"
  path   = "pki"
}

unit "ingress_pki" {
  source = "../../units/ingress-pki"
  path   = "ingress-pki"
}
