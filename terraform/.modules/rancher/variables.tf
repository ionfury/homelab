variable "rancher_version" {
  description = "Version of rancher to install."
  type        = string
}

variable "network_tld" {
  description = "Network TLD.  Must be managed by Cloudflare!"
  type        = string
}

variable "network_subdomain" {
  description = "Network subdomain to use."
  type        = string
}

variable "letsencrypt_issuer" {
  description = "Email address for letsencrypt issuer."
  type        = string
}

variable "github_oauth_client_id" {
  description = "ClientID for github oauth app."
  type        = string
}

variable "github_oauth_client_secret" {
  description = "Secret for github oauth app."
  type        = string
}

variable "github_user" {
  description = "Github user to use for oauth."
  type        = string
}

variable "github_user_id" {
  description = "Github userid to use for oauth."
  type        = string
}

variable "cert_manager_version" {
  type    = string
  default = "1.11.0"
}
