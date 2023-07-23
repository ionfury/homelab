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

variable "control_plane_cpu" {
  description = "CPU to allocate to control plane nodes."
  type        = string
  default     = "2"
}

variable "control_plane_memory" {
  description = "Memory to allocate to control plane nodes."
  type        = string
  default     = "8"
}

variable "control_plane_disk" {
  description = "Disk space to allocate to control plane nodes."
  type        = string
  default     = "60"
}

variable "control_plane_node_count" {
  description = "Number of nodes to create for the control plane."
  type        = number
  default     = 1
}

variable "network_name" {
  description = "Name of the network to run nodes on."
  type        = string
}

variable "worker_cpu" {
  description = "CPU to allocate to worker nodes."
  type        = string
  default     = "2"
}

variable "worker_memory" {
  description = "Memory to allocate to worker nodes."
  type        = string
  default     = "8"
}

variable "worker_disk" {
  description = "Disk space to allocate to worker nodes."
  type        = string
  default     = "60"
}

variable "worker_node_count" {
  description = "Number of nodes to create for the worker."
  type        = number
  default     = 1
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
  type = string
  default = "ubuntu"
}
