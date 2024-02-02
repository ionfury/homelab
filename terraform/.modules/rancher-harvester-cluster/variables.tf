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

variable "image_namespace" {
  type    = string
  default = "default"
}

variable "image_name" {
  type    = string
  default = "ubuntu20"
}

variable "image" {
  description = "Image to use for nodes."
  type        = string
  default     = "http://cloud-images.ubuntu.com/releases/focal/release/ubuntu-20.04-server-cloudimg-amd64.img"
}

variable "image_ssh_user" {
  description = "Default SSH user for image."
  type        = string
  default     = "ubuntu"
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
