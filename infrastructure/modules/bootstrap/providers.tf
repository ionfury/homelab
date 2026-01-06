provider "helm" {
  kubernetes = {
    host                   = var.kubeconfig.host
    client_certificate     = var.kubeconfig.client_certificate
    client_key             = var.kubeconfig.client_key
    cluster_ca_certificate = var.kubeconfig.cluster_ca_certificate
  }
}

provider "kubernetes" {
  host                   = var.kubeconfig.host
  client_certificate     = var.kubeconfig.client_certificate
  client_key             = var.kubeconfig.client_key
  cluster_ca_certificate = var.kubeconfig.cluster_ca_certificate
}

data "aws_ssm_parameter" "github_token" {
  name = var.github.token_store
}

provider "github" {
  owner = var.github.org
  token = data.aws_ssm_parameter.github_token.value
}

data "aws_ssm_parameter" "healthchecksio_api_key" {
  name = var.healthchecksio.api_key_store
}

provider "healthchecksio" {
  api_key = data.aws_ssm_parameter.healthchecksio_api_key.value
}
