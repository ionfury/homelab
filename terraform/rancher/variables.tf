

variable "default_network_tld" {
  type = string
}

variable "default_network_name" {
  type = string
}

variable "master_email" {
  type = string
}

variable "rancher_cluster_name" {
  type = string
}

variable "rancher_ssh_key_name" {
  type = string
}

variable "rancher_node_count" {
  type = number
}

variable "rancher_version" {
  type = string
}

variable "github_user" {
  type = string
}

variable "cloudflare_api_key_store" {
  type = string
}

variable "github_token_store" {
  type = string
}

variable "github_oauth_secret_store" {
  type = string
}

variable "github_oauth_clientid_store" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "aws_profile" {
  type = string
}

variable "unifi_management_address" {
  type        = string
  description = "Unifi management address controlling the local network."
}

variable "unifi_management_username" {
  type        = string
  description = "Unifi management address login username."
}

variable "unifi_management_password_store" {
  type        = string
  description = "Name of AWS parameter store containing the unifi management password."
}

variable "kubernetes_version" {
  type = string
}

variable "cert_manager_version" {
  type = string
}

variable "harvester_cluster_name" {
  type = string
}

variable "harvester_kubeconfig_path" {
  type = string
}

variable "healthchecksio_api_key_store" {
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
