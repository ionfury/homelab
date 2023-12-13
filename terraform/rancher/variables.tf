variable "tld" {
  description = "Top Level Domain name."
  type        = string
}

variable "aws" {
  description = "AWS account information."
  type = object({
    region  = string
    profile = string
  })
}

variable "rancher" {
  description = "Rancher cluster definition."
  type = object({
    cluster_name         = string
    ssh_key_name         = string
    rancher_version      = string
    kubernetes_version   = string
    cert_manager_version = string

    node_memory = string
    node_cpu    = number
    node_count  = number
  })
}

variable "github" {
  description = "Github account information."
  type = object({
    email                = string
    user                 = string
    name                 = string
    ssh_addr             = string
    ssh_pub              = string
    ssh_known_hosts      = string
    token_store          = string
    oauth_secret_store   = string
    oauth_clientid_store = string
    ssh_key_store        = string
  })
}

variable "unifi" {
  description = "Unifi account information."
  type = object({
    address        = string
    username       = string
    password_store = string
  })
}

variable "harvester" {
  type = object({
    cluster_name       = string
    kubeconfig_path    = string
    management_address = string
    network_name       = string

    storage = map(object({
      name       = string
      selector   = string
      is_default = bool
    }))

    inventory = map(object({
      primary_disk = string
      mac          = string
      host         = string
      uplink       = list(string)
      ip           = string
      port         = string
      insecure_tls = string
      credentials = object({
        store         = string
        username_path = string
        password_path = string
      })
    }))

    uplink     = list(string)
    node_count = number
  })
}

variable "cloudflare" {
  description = "Cloudflare account information"
  type = object({
    account_name  = string
    email         = string
    api_key_store = string
  })
}

variable "healthchecksio" {
  description = "Healthchecksio account information."
  type = object({
    api_key_store = string
  })
}

variable "external_secrets_access_key_store" {
  type = string
}
