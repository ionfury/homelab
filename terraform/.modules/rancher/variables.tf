variable "api_server_url" {
  description = "Address to cluster api server."
  type        = string
}

variable "cluster_client_cert" {
  description = "Client cert for cluster."
  type        = string
}

variable "cluster_client_key" {
  description = "Client key for cluster."
  type        = string
}

variable "cluster_ca_certificate" {
  description = "CA certificate for cluster."
  type        = string
}

variable "cloudflare_domain" {
  description = "Domain controlled by cloudflare."
  type        = string
}

variable "letsencrypt_issuer" {
  description = "Email address for letsencrypt issuer."
  type        = string
}

variable "rancher_domain_prefix" {
  description = "Prefix for the rancher domain."
  type        = string
  default     = "rancher"
}

variable "github_oauth_client_id" {
  description = "ClientID for github oauth app."
  type        = string
}

variable "github_oauth_client_secret" {
  description = "Secret for github oauth app."
  type        = string
}
