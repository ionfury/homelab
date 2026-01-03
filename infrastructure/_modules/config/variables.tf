variable "name" {
  description = "The name of the cluster."
  type        = string
}

variable "features" {
  description = "Enabled cluster features."
  type        = set(string)

  validation {
    condition     = alltrue([for feature in var.features : contains(["gateway-api", "longhorn", "prometheus", "spegel"], feature)])
    error_message = "Each feature must be one of: gateway-api, longhorn, prometheus, spegel."
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
    error_message = "timeservers must contain at least one valid NTP server address."
    condition     = length(var.networking.timeservers) > 0
  }

  validation {
    error_message = "internal_tld and external_tld must be valid domain names."
    condition = alltrue([
      can(regex("^(?!-)[A-Za-z0-9-]{1,63}(?<!-)\\.(?:[A-Za-z]{2,})$", var.networking.internal_tld)),
      can(regex("^(?!-)[A-Za-z0-9-]{1,63}(?<!-)\\.(?:[A-Za-z]{2,})$", var.networking.external_tld)),
    ])
  }
}

variable "machines" {
  description = "Machine inventory for the cluster."
  type = map(object({
    cluster = string
    type    = string
    install = object({
      selector = string
      data = object({
        enabled = bool
        tags    = list(string)
      })
    })
    disks = list(object({
      device     = string
      mountpoint = string
      tags       = list(string)
    }))
    interfaces = list(object({
      id           = string
      hardwareAddr = string
      addresses    = list(object({ ip = string }))
    }))
  }))

  validation {
    error_message = "Each machine type must be one of: controlplane, worker."
    condition     = alltrue([for m in values(var.machines) : contains(["controlplane", "worker"], m.type)])
  }

  validation {
    error_message = "Each machine must have at least one interface."
    condition     = alltrue([for m in values(var.machines) : length(m.interfaces) > 0])
  }

  validation {
    error_message = "Each machine must have at least one IP address assigned to an interface."
    condition     = alltrue([for m in values(var.machines) : length(flatten([for iface in m.interfaces : iface.addresses])) > 0])
  }

  validation {
    error_message = "hardwareAddr must be a valid MAC address."
    condition     = alltrue([for m in values(var.machines) : alltrue([for iface in m.interfaces : can(regex("^([0-9a-fA-F]{2}:){5}([0-9a-fA-F]{2})$", iface.hardwareAddr))])])
  }
}

variable "versions" {
  description = "The versions to use for the cluster."
  type = object({
    talos       = string
    kubernetes  = string
    cilium      = string
    gateway_api = string
    flux        = string
    prometheus  = string
  })

  validation {
    error_message = "Talos version must be a semver prefixed with a 'v'."
    condition     = can(regex("^v\\d+\\.\\d+\\.\\d+(-[0-9A-Za-z-.]+)?$", var.versions.talos))
  }

  validation {
    error_message = "Kubernetes version must be a semver not prefixed with 'v'."
    condition     = can(regex("^\\d+\\.\\d+\\.\\d+(-[0-9A-Za-z-.]+)?$", var.versions.kubernetes))
  }

  validation {
    error_message = "Cilium version must be a semver not prefixed with 'v'."
    condition     = can(regex("^\\d+\\.\\d+\\.\\d+(-[0-9A-Za-z-.]+)?$", var.versions.cilium))
  }

  validation {
    error_message = "Gateway API version must be a semver prefixed with 'v'."
    condition     = can(regex("^v\\d+\\.\\d+\\.\\d+(-[0-9A-Za-z-.]+)?$", var.versions.gateway_api))
  }

  validation {
    error_message = "Flux version must be a semver prefixed with a 'v'."
    condition     = can(regex("^v\\d+\\.\\d+\\.\\d+(-[0-9A-Za-z-.]+)?$", var.versions.flux))
  }

  validation {
    error_message = "Prometheus version must be a semver not prefixed with 'v'."
    condition     = can(regex("^\\d+\\.\\d+\\.\\d+(-[0-9A-Za-z-.]+)?$", var.versions.prometheus))
  }
}

variable "local_paths" {
  description = "The local paths to use for the cluster."
  type = object({
    talos      = string
    kubernetes = string
  })
}

variable "values" {
  description = "Map of SSM parameter values keyed by name."
  type        = map(string)
}
