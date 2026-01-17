variable "name" {
  description = "The name of the cluster."
  type        = string
}

variable "features" {
  description = "Enabled cluster features."
  type        = set(string)
  default     = ["gateway-api", "longhorn", "prometheus", "spegel"]

  validation {
    condition     = alltrue([for feature in var.features : contains(["gateway-api", "longhorn", "prometheus", "spegel"], feature)])
    error_message = "Each feature must be one of: gateway-api, longhorn, prometheus, spegel."
  }
}

variable "storage_provisioning" {
  description = "Storage provisioning mode: 'normal' for production sizes, 'minimal' for dev/test sizes."
  type        = string
  default     = "normal"

  validation {
    condition     = contains(["normal", "minimal"], var.storage_provisioning)
    error_message = "storage_provisioning must be 'normal' or 'minimal'."
  }
}

variable "networking" {
  description = "Networking configuration for the cluster."
  type = object({
    id                  = number
    internal_tld        = string
    external_tld        = string
    node_subnet         = string
    pod_subnet          = string
    service_subnet      = string
    vip                 = string
    ip_pool_start       = string
    internal_ingress_ip = string
    external_ingress_ip = string
    ip_pool_stop        = string
    nameservers         = list(string)
    timeservers         = list(string)
  })

  validation {
    error_message = "node_subnet, pod_subnet, and service_subnet must be valid CIDR notation."
    condition = alltrue([
      can(cidrhost(var.networking.node_subnet, 1)),
      can(cidrhost(var.networking.pod_subnet, 1)),
      can(cidrhost(var.networking.service_subnet, 1)),
    ])
  }

  validation {
    error_message = "vip, ip_pool_start, internal_ingress_ip, external_ingress_ip, and ip_pool_stop must be valid IP addresses within the node_subnet."
    condition = alltrue([
      can(cidrhost(var.networking.node_subnet, 1)) && cidrcontains(var.networking.node_subnet, var.networking.vip),
      can(cidrhost(var.networking.node_subnet, 1)) && cidrcontains(var.networking.node_subnet, var.networking.ip_pool_start),
      can(cidrhost(var.networking.node_subnet, 1)) && cidrcontains(var.networking.node_subnet, var.networking.internal_ingress_ip),
      can(cidrhost(var.networking.node_subnet, 1)) && cidrcontains(var.networking.node_subnet, var.networking.external_ingress_ip),
      can(cidrhost(var.networking.node_subnet, 1)) && cidrcontains(var.networking.node_subnet, var.networking.ip_pool_stop),
    ])
  }

  validation {
    error_message = "nameservers must contain at least one valid IP address."
    condition     = length(var.networking.nameservers) > 0 && alltrue([for ns in var.networking.nameservers : can(regex("^((25[0-5]|(2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9]))\\.){3}(25[0-5]|(2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9]))$", ns))])
  }

  validation {
    error_message = "timeservers must contain at least one entry."
    condition     = length(var.networking.timeservers) > 0
  }

  validation {
    error_message = "internal_tld and external_tld must be valid domain names."
    condition = alltrue([
      can(regex("^[a-zA-Z0-9][a-zA-Z0-9.-]+[a-zA-Z0-9]$", var.networking.internal_tld)),
      can(regex("^[a-zA-Z0-9][a-zA-Z0-9.-]+[a-zA-Z0-9]$", var.networking.external_tld)),
    ])
  }
}

variable "machines" {
  description = "Machine inventory - pass inventory.hcl hosts directly."
  type = map(object({
    cluster = string
    type    = string
    install = object({
      selector     = string
      architecture = optional(string, "amd64")
      platform     = optional(string, "metal")
      sbc          = optional(string, "")
      secureboot   = optional(bool, false)
      data = optional(object({
        enabled = bool
        tags    = list(string)
      }), { enabled = false, tags = [] })
    })
    disks = optional(list(object({
      device     = string
      mountpoint = string
      tags       = list(string)
    })), [])
    interfaces = list(object({
      id           = string
      hardwareAddr = string
      addresses = list(object({
        ip = string
      }))
    }))
  }))
}

variable "versions" {
  description = "Component versions for the cluster."
  type = object({
    talos       = string
    kubernetes  = string
    cilium      = string
    gateway_api = string
    flux        = string
    prometheus  = string
  })

  validation {
    error_message = "Talos version must be a semver prefixed with 'v'."
    condition     = can(regex("^v\\d+\\.\\d+\\.\\d+(-[0-9A-Za-z-.]+)?$", var.versions.talos))
  }

  validation {
    error_message = "Kubernetes version must be a semver without 'v' prefix."
    condition     = can(regex("^\\d+\\.\\d+\\.\\d+(-[0-9A-Za-z-.]+)?$", var.versions.kubernetes))
  }

  validation {
    error_message = "Cilium version must be a semver without 'v' prefix."
    condition     = can(regex("^\\d+\\.\\d+\\.\\d+(-[0-9A-Za-z-.]+)?$", var.versions.cilium))
  }

  validation {
    error_message = "Gateway API version must be a semver prefixed with 'v'."
    condition     = can(regex("^v\\d+\\.\\d+\\.\\d+(-[0-9A-Za-z-.]+)?$", var.versions.gateway_api))
  }

  validation {
    error_message = "Flux version must be a semver prefixed with 'v'."
    condition     = can(regex("^v\\d+\\.\\d+\\.\\d+(-[0-9A-Za-z-.]+)?$", var.versions.flux))
  }

  validation {
    error_message = "Prometheus version must be a semver without 'v' prefix."
    condition     = can(regex("^\\d+\\.\\d+\\.\\d+(-[0-9A-Za-z-.]+)?$", var.versions.prometheus))
  }
}

variable "local_paths" {
  description = "Local filesystem paths for configuration output."
  type = object({
    talos      = string
    kubernetes = string
  })
  default = {
    talos      = "~/.talos"
    kubernetes = "~/.kube"
  }
}
/*
variable "account_values" {
  description = "Secret values to bind to accounts."
  type        = map(string)
  sensitive   = true
  default     = {}
}
*/

variable "accounts" {
  description = "Account configuration from accounts.hcl."
  type = object({
    unifi = object({
      address       = string
      site          = string
      api_key_store = string
    })
    github = object({
      org             = string
      repository      = string
      repository_path = string
      token_store     = string
    })
    external_secrets = object({
      id_store     = string
      secret_store = string
    })
    healthchecksio = object({
      api_key_store = string
    })
  })
}

variable "ssm_output_path" {
  description = "AWS SSM parameter path prefix for storing cluster credentials."
  type        = string
  default     = "/homelab/infrastructure/clusters"
}

variable "on_destroy" {
  description = "Talos node destruction behavior."
  type = object({
    graceful = bool
    reboot   = bool
    reset    = bool
  })
  default = {
    graceful = false
    reboot   = true
    reset    = true
  }
}
