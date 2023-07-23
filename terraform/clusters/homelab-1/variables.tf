variable "cluster_name" {
  description = "Name of the cluster."
  type        = string
}

variable "harvester_cluster_name" {
  type = string
}

variable "default_network_name" {
  type = string
}

variable "aws_region" {
  type        = string
  description = "AWS Region to use."
}

variable "aws_profile" {
  type        = string
  description = "AWS profile to use vis `~/.aws`."
}

variable "default_network_tld" {
  type = string
}

variable "github_ssh_addr" {
  type = string
}

variable "github_ssh_key_store" {
  type = string
}

variable "github_ssh_pub" {
  type = string
}

variable "github_ssh_known_hosts" {
  type = string
}

variable "healthchecksio_api_key_store" {
  type = string
}

variable "external_secrets_access_key_name" {
  type = string
}
