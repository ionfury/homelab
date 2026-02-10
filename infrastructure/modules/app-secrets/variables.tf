variable "name" {
  description = "Application name (used in resource naming and descriptions)"
  type        = string
}

variable "secrets" {
  description = "Map of secret names to generation parameters"
  type = map(object({
    length  = number
    special = bool
  }))
}

variable "ssm_parameter_path" {
  description = "AWS SSM parameter path for storing the secrets JSON"
  type        = string
}

variable "local_backup_path" {
  description = "Local file path for secrets backup (directory must exist)"
  type        = string
}
