variable "aws" {
  type = object({
    region  = string
    profile = string
  })
}

variable "master_email" {
  description = "Master email used for everything."
  type        = string
}

variable "cloudflare_api_key_store" {
  type = string
}

variable "tld" {
  description = "Top Level Domain name."
  type        = string
}
