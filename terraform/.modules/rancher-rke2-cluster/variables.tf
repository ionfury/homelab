variable "name" {
  description = "Name of the RKE2 cluster."
  type = string
}

variable "namespace" {
  description = "Namespace to put the cluster."
  type = string
  default = "default"
}

variable "kubernetes_version" {
  description = "Version of kubernetes to use."
  type = string
  default = "v1.24.3+rke2r1"
}

variable "control_plane_cpu" {
  description = "CPU to allocate to control plane nodes."
  type = string
  default = "2"
}

variable "control_plane_memory" {
  description = "Memory to allocate to control plane nodes."
  type = string
  default = "8"
}

variable "control_plane_disk" {
  description = "Disk space to allocate to control plane nodes."
  type = string
  default = "30"
}

variable "control_plane_node_count" {
  description = "Number of nodes to create for the control plane."
  type = number
  default = 1
}

variable "network_name" {
  description = "Name of the network to run nodes on."
  type = string
}

variable "worker_cpu" {
  description = "CPU to allocate to worker nodes."
  type = string
  default = "2"
}

variable "worker_memory" {
  description = "Memory to allocate to worker nodes."
  type = string
  default = "8"
}

variable "worker_disk" {
  description = "Disk space to allocate to worker nodes."
  type = string
  default = "30"
}

variable "worker_node_count" {
  description = "Number of nodes to create for the worker."
  type = number
  default = 1
}

variable "github_url" {
  description = "Url for github to create flux cluster"
  type = string
  default = "https://github.com/ionfury/homelab"
}

variable "github_ssh_pub" {
  description = "SSH Pub for github_ssh_key."
  type = string
}

variable "github_ssh_key" {
  description = "SSH key for accessing github_url."
  type = string
}

variable "rancher_admin_token" {
  description = "Admin token for accessing rancher_admin_url"
  type = string
}

variable "rancher_admin_url" {
  description = "URL of rancher server"
  type = string
}

variable "access_key_id" {
  description = "Access key ID for external secrets"
  type = string
}

variable "access_key_secret" {
  description = "Access key secret for external secrets"
  type = string
}
