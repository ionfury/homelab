data "kubernetes_secret_v1" "minio_root" {
  metadata {
    name      = "minio-secret"
    namespace = "storage"
  }
}

provider "minio" {
  minio_ssl      = true
  minio_server   = "s3.tomnowak.work"
  minio_user     = data.kubernetes_secret_v1.minio_root.data["MINIO_ROOT_USER"]
  minio_password = data.kubernetes_secret_v1.minio_root.data["MINIO_ROOT_PASSWORD"]
}

provider "kubernetes" {
  config_path    = "~/.kube/homelab-1.yaml"
  config_context = "homelab-1"
}
