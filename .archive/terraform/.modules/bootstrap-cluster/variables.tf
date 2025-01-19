variable "cluster_name" {
  description = "Name of the cluster."
  type        = string
}

variable "external_secrets_access_key_id" {
  type = string
}

variable "external_secrets_access_key_secret" {
  type = string
}

variable "github_ssh_pub" {
  description = "SSH Pub for github_ssh_key."
  type        = string
}

variable "github_ssh_key" {
  description = "SSH key for accessing github_url."
  type        = string
}

variable "known_hosts" {
  type = string
}
