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

variable "restore" {
  description = "Snapshot to restore to the cluster."
  type = object({
    generation         = number
    name               = string
    restore_rke_config = string
  })
  default = null
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
    image                          = string
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

variable "node_base_image" {
  description = "Configuration for node base images.  Providing these options allow for 'toggling' harvester images."
  type = map(object({
    name      = string
    namespace = string
    url       = string
    ssh_user  = string
  }))
}
