output "ssm_parameter_path" {
  description = "SSM parameter path where secrets are stored"
  value       = aws_ssm_parameter.secrets.name
}

output "ssm_parameter_arn" {
  description = "SSM parameter ARN"
  value       = aws_ssm_parameter.secrets.arn
}
