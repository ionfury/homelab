variable "cluster_name" {
  description = "Name of the cluster."
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for the cluster."
  type        = string
}

variable "tld" {
  description = "Top Level Domain name."
  type        = string
}

variable "control_plane" {
  type = object({
    nodes  = number
    cpu    = number
    memory = number
    disk   = number
  })
}

variable "worker" {
  type = object({
    nodes  = number
    cpu    = number
    memory = number
    disk   = number
  })
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
    node_count         = number

    storage = map(object({
      name       = string
      selector   = string
      is_default = bool
    }))
  })
}

variable "networks" {
  type = map(object({
    name = string
    vlan = number
    cidr = string
  }))
}

variable "github" {
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

variable "cloudflare" {
  type = object({
    account_name  = string
    email         = string
    api_key_store = string
  })
}

variable "healthchecksio" {
  type = object({
    api_key_store = string
  })
}


variable "external_secrets_access_key_store" {
  type = string
}
