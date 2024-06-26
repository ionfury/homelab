variable "harvester_cluster_name" {
  description = "Name of the Havester cluster."
  type        = string
}

variable "rancher_admin_token" {
  description = "Admin token for accessing rancher_admin_url"
  type        = string
}

variable "rancher_admin_url" {
  description = "URL of rancher server"
  type        = string
}

variable "name" {
  description = "Name of the RKE2 cluster."
  type        = string
}

variable "namespace" {
  description = "Namespace to put the cluster."
  type        = string
  default     = "default"
}

variable "kubernetes_version" {
  description = "Version of kubernetes to use."
  type        = string
  default     = "v1.24.3+rke2r1"
}
variable "network_name" {
  description = "Name of the network to run nodes on."
  type        = string
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

variable "restore" {
  description = "Snapshot to restore to the cluster."
  type = object({
    generation         = number
    name               = string
    restore_rke_config = string
  })
  default = null
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
