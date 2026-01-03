variable "params" {
  description = "SSM parameters to write"
  type = map(object({
    name        = string
    description = optional(string)
    type        = string
    value       = string
  }))
  sensitive = true
}
