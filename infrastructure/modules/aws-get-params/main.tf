data "aws_ssm_parameter" "this" {
  for_each = var.names
  name     = each.value
}
