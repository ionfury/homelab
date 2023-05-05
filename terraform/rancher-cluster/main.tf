module "cluster" {
  source                 = "../.modules/rke-cluster"
  name                   = "rancher"
  nodes_count            = 1
  harvester_ssh_key_name = "id-rsa-homelab-ssh-mac"
  harvester_network_name = "harvester"
  storage_class_name     = "rancher-vm-storage"

  tags = {
    managed-by-terraform = true
  }

  providers = {
    harvester = harvester
    rke       = rke
    tls       = tls
    aws       = aws
  }
}

data "aws_ssm_parameter" "github_oauth_secret" {
  name = "github-oauth-rancher-tomnowak-work-secret"
}

data "aws_ssm_parameter" "github_oauth_clientid" {
  name = "github-oauth-rancher-tomnowak-work-clientid"
}

module "rancher" {
  source                 = "../.modules/rancher"
  api_server_url         = module.cluster.api_server_url
  cluster_client_cert    = module.cluster.cluster_client_cert
  cluster_client_key     = module.cluster.cluster_client_key
  cluster_ca_certificate = module.cluster.cluster_ca_certificate

  cloudflare_domain     = "tomnowak.work"
  rancher_domain_prefix = "rancher"
  letsencrypt_issuer    = "ionfury@gmail.com"

  github_oauth_client_id     = data.aws_ssm_parameter.github_oauth_clientid.value
  github_oauth_client_secret = data.aws_ssm_parameter.github_oauth_secret.value

  providers = {
    github     = github
    cloudflare = cloudflare
  }

}

