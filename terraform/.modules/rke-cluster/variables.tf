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

variable "harvester_ssh_key_name" {
  description = "Harvester SSH key to allow access to the node by name."
  type        = string
}

variable "harvester_network_name" {
  description = "Name of the harvester network to use."
  type        = string
}

variable "storage_class_name" {
  description = "Name of the storage class to use for created VMs"
  type        = string
}

variable "tags" {
  type = map(string)
}
