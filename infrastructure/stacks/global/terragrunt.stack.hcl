# Global stack - cross-cluster infrastructure independent of individual cluster lifecycles
# Provisions resources shared across all clusters: S3 backup buckets, PKI certificates.

locals {
  # All clusters that need shared infrastructure
  clusters = ["dev", "integration", "live"]
}

unit "velero_storage" {
  source = "../../units/velero-storage"
  path   = "velero-storage"

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

unit "lldap_secrets" {
  source = "../../units/lldap-secrets"
  path   = "lldap-secrets"
}

unit "authelia_secrets" {
  source = "../../units/authelia-secrets"
  path   = "authelia-secrets"
}
