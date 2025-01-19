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

variable "cert_manager_version" {
  type    = string
  default = "1.11.0"
}
