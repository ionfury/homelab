# App secrets module - generates random secrets and stores them in AWS SSM
# Secrets are generated once and persist across cluster rebuilds via SSM.
# Used for application credentials that must remain stable (e.g. LLDAP key seed).

resource "random_password" "secrets" {
  for_each = var.secrets

  length  = each.value.length
  special = each.value.special
}

# Store all secrets as a single JSON SecureString in SSM
# ExternalSecrets can extract individual keys via the `property` field
resource "aws_ssm_parameter" "secrets" {
  name        = var.ssm_parameter_path
  description = "Application secrets for ${var.name}"
  type        = "SecureString"

  value = jsonencode({
    for k, v in random_password.secrets : k => v.result
  })

  tags = {
    managed-by = "opentofu"
    purpose    = "app-secrets"
    app-name   = var.name
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [value]
  }
}

# Local backup for disaster recovery
resource "local_sensitive_file" "secrets_backup" {
  filename = var.local_backup_path

  content = jsonencode({
    app_name     = var.name
    ssm_path     = var.ssm_parameter_path
    generated_at = timestamp()
    secrets      = { for k, v in random_password.secrets : k => v.result }
  })

  file_permission = "0600"
}
