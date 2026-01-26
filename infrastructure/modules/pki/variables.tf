variable "ca_name" {
  description = "Name identifier for the CA (used in resource naming and descriptions)"
  type        = string
}

variable "ca_subject" {
  description = "X.509 subject for the CA certificate"
  type = object({
    organization = string
    common_name  = string
  })
}

variable "validity_days" {
  description = "Certificate validity period in days"
  type        = number
  default     = 3650 # 10 years
}

variable "ssm_parameter_path" {
  description = "AWS SSM parameter path for storing the CA certificate and key"
  type        = string
}

variable "local_backup_path" {
  description = "Local file path for CA backup (directory must exist)"
  type        = string
}
