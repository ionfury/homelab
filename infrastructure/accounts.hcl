locals {
  unifi = {
    address       = "https://192.168.1.1"
    site          = "default"
    api_key_store = "/homelab/infrastructure/accounts/unifi/api-key"
  }

  github = {
    org             = "ionfury"
    repository      = "homelab"
    repository_path = "kubernetes/clusters"
    token_store     = "/homelab/infrastructure/accounts/github/token"
  }

  cloudflare = {
    account         = "homelab"
    email           = "ionfury@gmail.com"
    api_token_store = "/homelab/infrastructure/accounts/cloudflare/token"
    zone_id         = "799905ff93d585a9a0633949275cbf98"
  }

  #external_secrets = {
  #  id_store     = "/homelab/infrastructure/accounts/external-secrets/id"
  #  secret_store = "/homelab/infrastructure/accounts/external-secrets/secret"
  #}

  healthchecksio = {
    api_key_store = "/homelab/infrastructure/accounts/healthchecksio/api-key"
  }
}

