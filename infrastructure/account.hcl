locals {

  aws = {
    region  = "us-east-2"
    profile = "terragrunt"
  }

  unifi_address        = "https://192.168.1.1"
  unifi_site           = "default"
  unifi_password_store = "/homelab/unifi/terraform/password"
  unifi_username_store = "/homelab/unifi/terraform/username"

  github_org             = "ionfury"
  github_repository      = "homelab"
  github_repository_path = "kubernetes/clusters"
  github_dev_token_path  = "/homelab/github/ionfury/homelab-flux-dev-token"

  parameters = [local.unifi_username_store, local.unifi_password_store, local.github_dev_token_path]

  unifi = {
    address        = "https://192.168.1.1"
    username_store = "/homelab/unifi/terraform/username"
    password_store = "/homelab/unifi/terraform/password"
    site           = "default"
  }

  cloudflare = {
    account_name  = "homelab"
    email         = "ionfury@gmail.com"
    api_key_store = "cloudflare-api-key"
  }
}
