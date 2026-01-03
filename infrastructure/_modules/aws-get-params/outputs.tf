output "values" {
  description = "Map of SSM parameter values keyed by name"
  value = {
    for name, param in data.aws_ssm_parameter.this :
    name => param.value
  }
  sensitive = true
}
