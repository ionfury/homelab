

module "minio_bucket" {
  for_each    = toset(var.minio.buckets)
  source      = "../.modules/minio-bucket"
  bucket_name = each.key
  is_public   = false
  providers = {
    minio = minio
  }
}

resource "kubernetes_secret_v1" "secrets" {
  for_each = module.minio_bucket

  metadata {
    name      = "minio-bucket-${each.key}"
    namespace = "storage"
    annotations = {
      "replicator.v1.mittwald.de/replication-allowed"            = "true"
      "replicator.v1.mittwald.de/replication-allowed-namespaces" = ".*"
    }
  }

  data = {
    id         = each.value.bucket.id
    access_key = each.value.bucket.access_key
    secret_key = each.value.bucket.secret_key
  }
}
