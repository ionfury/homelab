variable "aws" {
  type = object({
    region  = string
    profile = string
  })
}

variable "cloudflare" {
  description = "Configuration for Cloudflare"
  type = object({
    account_name  = string
    email         = string
    api_key_store = string
  })
}

variable "tld" {
  description = "Top Level Domain name."
  type        = string
}
