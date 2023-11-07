variable "aws_region" {
  type        = string
  description = "AWS Region to use."
}

variable "aws_profile" {
  type        = string
  description = "AWS profile to use vis `~/.aws`."
}

variable "master_email" {
  type = string
}

variable "cloudflare_api_key_store" {
  type = string
}

variable "tld" {
  type = string
}
