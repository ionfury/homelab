locals {
  tld = "tomnowak.work"

  aws = {
    region  = "us-east-2"
    profile = "terragrunt"
  }

  unifi = {
    address        = "https://192.168.1.1"
    username_store = "/homelab/infrastructure/accounts/unifi/username"
    password_store = "/homelab/infrastructure/accounts/unifi/password"
    api_key_store  = "/homelab/infrastructure/accounts/unifi/api-key"
    site           = "default"
  }

  github = {
    org             = "ionfury"
    repository      = "homelab"
    repository_path = "kubernetes/clusters"
    token_store     = "/homelab/infrastructure/accounts/github/token"
  }

  cloudflare = {
    account       = "homelab"
    email         = "ionfury@gmail.com"
    api_key_store = "/homelab/infrastructure/accounts/cloudflare/api-key"
  }

  external_secrets = {
    id_store     = "/homelab/infrastructure/accounts/external-secrets/id"
    secret_store = "/homelab/infrastructure/accounts/external-secrets/secret"
  }

  healthchecksio = {
    api_key_store = "/homelab/infrastructure/accounts/healthchecksio/api-key"
  }
}
