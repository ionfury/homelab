data "aws_ssm_parameter" "external_secrets_id" {
  name = var.external_secrets.id_store
}

data "aws_ssm_parameter" "external_secrets_secret" {
  name = var.external_secrets.secret_store
}

resource "kubernetes_secret" "external_secrets_access_key" {
  metadata {
    name      = "external-secrets-access-key"
    namespace = "kube-system"
  }

  data = {
    access_key        = data.aws_ssm_parameter.external_secrets_id.value
    secret_access_key = data.aws_ssm_parameter.external_secrets_secret.value
  }
}
