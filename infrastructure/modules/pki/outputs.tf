output "ca_cert_pem" {
  description = "PEM-encoded CA certificate"
  value       = tls_self_signed_cert.ca.cert_pem
}

output "ssm_parameter_path" {
  description = "SSM parameter path where CA is stored"
  value       = aws_ssm_parameter.ca.name
}

output "ssm_parameter_arn" {
  description = "SSM parameter ARN"
  value       = aws_ssm_parameter.ca.arn
}

output "local_backup_path" {
  description = "Local file path where CA backup was written"
  value       = local_sensitive_file.ca_backup.filename
}

output "validity" {
  description = "Certificate validity information"
  value = {
    not_before = tls_self_signed_cert.ca.validity_start_time
    not_after  = tls_self_signed_cert.ca.validity_end_time
  }
}
