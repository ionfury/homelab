
resource "aws_iam_user" "external_secrets_user" {
  name = "k8s-external-secrets-${var.harvester.cluster_name}"

  tags = {
    assignable-by-terragrunt = "true"
  }
}

data "aws_iam_policy" "external_secrets_policy" {
  name = "ssm-k8s-reader"
}

resource "aws_iam_user_policy_attachment" "external_secrets_policy_attachment" {
  user       = aws_iam_user.external_secrets_user.name
  policy_arn = data.aws_iam_policy.external_secrets_policy.arn
}

resource "aws_iam_access_key" "external_secrets_access_key" {
  user = aws_iam_user.external_secrets_user.name
}

data "aws_ssm_parameter" "github_ssh_key" {
  name = var.github.ssh_key_store
}

module "bootstrap" {
  source = "../.modules/bootstrap-cluster"

  cluster_name = var.harvester.cluster_name

  github_ssh_pub = var.github.ssh_pub
  github_ssh_key = data.aws_ssm_parameter.github_ssh_key.value
  known_hosts    = var.github.ssh_known_hosts

  external_secrets_access_key_id     = aws_iam_access_key.external_secrets_access_key.id
  external_secrets_access_key_secret = aws_iam_access_key.external_secrets_access_key.secret

  providers = {
    flux           = flux
    healthchecksio = healthchecksio
    kubernetes     = kubernetes
  }
}
