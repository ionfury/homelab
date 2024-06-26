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
      name       = string
      selector   = string
      is_default = bool
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

variable "machine_pools" {
  type = map(object({
    min_size                       = number
    max_size                       = number
    node_startup_timeout_seconds   = number
    unhealthy_node_timeout_seconds = number
    max_unhealthy                  = string
    machine_labels                 = map(string)
    vm_affinity_b64                = string
    gpu_enabled                    = bool
    resources = object({
      cpu    = number
      memory = number
      disk   = number
    })
    roles = object({
      control_plane = bool
      etcd          = bool
      worker        = bool
    })
  }))
}

variable "node_base_image_version" {
  description = "Specify which node base image version to use: 'this' or 'next'"
  type        = string
  default     = "this"

  validation {
    condition     = contains(["this", "next"], var.node_base_image_version)
    error_message = "The node_base_image_version must be either 'this' or 'next'."
  }
}

variable "node_base_image" {
  description = "Configuration for node base images.  Providing these options allow for 'toggling' harvester images."
  type = object({
    this = object({
      name      = string
      namespace = string
      url       = string
      ssh_user  = string
    })
    next = object({
      name      = string
      namespace = string
      url       = string
      ssh_user  = string
    })
  })
}

variable "restore" {
  description = "Snapshot to restore to the cluster."
  type = object({
    generation         = number
    name               = string
    restore_rke_config = string
  })
  default = null
}
