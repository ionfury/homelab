resource "kubernetes_secret" "external_secrets_access_key" {
  metadata {
    name      = "external-secrets-access-key"
    namespace = "kube-system"
  }

  data = {
    access_key        = var.external_secrets.id
    secret_access_key = var.external_secrets.secret
  }
}
