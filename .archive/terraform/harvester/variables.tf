variable "tld" {
  description = "Top Level Domain name."
  type        = string
}

variable "aws" {
  type = object({
    region  = string
    profile = string
  })
}

variable "harvester" {
  type = object({
    cluster_name       = string
    kubeconfig_path    = string
    management_address = string
    network_name       = string

    storage = map(object({
      name           = string
      selector       = string
      is_default     = bool
      replicas       = number
      reclaim_policy = string
    }))

    inventory = map(object({
      ip           = string
      primary_disk = string
      uplinks      = list(string)

      ipmi = object({
        mac          = string
        ip           = string
        port         = string
        host         = string
        insecure_tls = string
        credentials = object({
          store         = string
          username_path = string
          password_path = string
        })
      })
    }))
  })
}

variable "networks" {
  type = map(object({
    name       = string
    vlan       = number
    cidr       = string
    gateway    = string
    netmask    = string
    dhcp_cidr  = string
    dhcp_start = number
    dhcp_stop  = number
    site       = string
  }))
}

variable "public_ssh_keys" {
  type = list(object({
    description = string
    name        = string
    public_key  = string
  }))
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

variable "healthchecksio" {
  description = "Healthchecksio account information."
  type = object({
    api_key_store = string
  })
}

