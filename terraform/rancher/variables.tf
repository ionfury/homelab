variable "tld" {
  description = "Top Level Domain name."
  type        = string
}

variable "master_email" {
  description = "Master email used for everything."
  type        = string
}

variable "aws" {
  type = object({
    region  = string
    profile = string
  })
}

variable "rancher" {
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
  type = object({
    user            = string
    name            = string
    ssh_addr        = string
    ssh_pub         = string
    ssh_known_hosts = string
  })
}

variable "unifi" {
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
    node_count         = number

    storage = map(object({
      name       = string
      selector   = string
      is_default = bool
    }))
  })
}

variable "cloudflare_api_key_store" {
  type = string
}

variable "github_token_store" {
  type = string
}

variable "github_ssh_key_store" {
  type = string
}

variable "github_oauth_secret_store" {
  type = string
}

variable "github_oauth_clientid_store" {
  type = string
}

variable "healthchecksio_api_key_store" {
  type = string
}

variable "external_secrets_access_key_store" {
  type = string
}
