locals {
  tld = "tomnowak.work"

  aws = {
    region  = "us-east-2"
    profile = "terragrunt"
  }

  unifi = {
    address        = "https://192.168.1.1"
    username_store = "/homelab/unifi/terraform/username" # /homelab/infrastructure/unifi/username
    password_store = "/homelab/unifi/terraform/password" # /homelab/infrastructure/unifi/password
    site           = "default"
  }

  github = {
    org             = "ionfury"
    repository      = "homelab"
    repository_path = "kubernetes/clusters"
    token_store     = "/homelab/github/ionfury/homelab-flux-dev-token" # /homelab/infrastructure/github/token
  }

  cloudflare = {
    account       = "homelab"
    email         = "ionfury@gmail.com"
    api_key_store = "/homelab/cloudflare/api-key" # /homelab/infrastructure/cloudflare/api-key
  }

  external_secrets = {
    id_store     = "/homelab/kubernetes/live/external-secrets/id"     # /homelab/infrastructure/external-secrets/id
    secret_store = "/homelab/kubernetes/live/external-secrets/secret" # /homelab/infrastructure/external-secrets/secret
  }

  healthchecksio = {
    api_key_store = "/homelab/healthchecksio/api-key" # /homelab/infrastructure/healthchecksio/api-key
  }
}
