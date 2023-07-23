variable "name" {
  description = "Name to use for nodes and resources."
  type        = string
}

variable "namespace" {
  description = "Harvester namespace to use for all resources."
  type        = string
  default     = "default"
}

variable "nodes_count" {
  description = "Number of mixed nodes to deploy with both control plane and worker roles."
  type        = string
}

variable "node_cpu" {
  description = "CPU to allocate for each node."
  type        = number
  default     = 2
}

variable "node_memory" {
  description = "Memory to allocate for each node."
  type        = string
  default     = "8Gi"
}

variable "node_disk" {
  description = "Disk space to allocate for each node."
  type        = string
  default     = "60Gi"
}

variable "harvester_ssh_key_name" {
  description = "Harvester SSH key to allow access to the node by name."
  type        = string
}

variable "harvester_network_name" {
  description = "Name of the harvester network to use."
  type        = string
}

variable "base_image" {
  description = "Base image to use for nodes."
  type        = string
  default     = "http://cloud-images.ubuntu.com/releases/focal/release/ubuntu-20.04-server-cloudimg-amd64.img"
}

variable "kubernetes_version" {
  type = string
}

variable "tags" {
  type = map(string)
}
