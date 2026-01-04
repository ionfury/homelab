
resource "aws_ssm_parameter" "this" {
  for_each = var.params

  name        = each.value.name
  description = try(each.value.description, null)
  type        = each.value.type
  value       = each.value.value

  tags = {
    managed-by = "terraform"
  }
}
