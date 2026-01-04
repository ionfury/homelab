output "names" {
  description = "Names of parameters written"
  value       = { for k, v in aws_ssm_parameter.this : k => v.name }
}
