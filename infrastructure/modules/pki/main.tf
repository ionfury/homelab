# PKI module - generates CA certificates and stores them in AWS SSM
# Single root CA that all downstream certificates flow from.

# Generate ECDSA P-256 private key
resource "tls_private_key" "ca" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

# Generate self-signed root CA certificate
resource "tls_self_signed_cert" "ca" {
  private_key_pem = tls_private_key.ca.private_key_pem

  subject {
    organization = var.ca_subject.organization
    common_name  = var.ca_subject.common_name
  }

  validity_period_hours = var.validity_days * 24

  is_ca_certificate = true

  allowed_uses = [
    "cert_signing",
    "crl_signing",
  ]
}

# Store in AWS SSM as JSON with base64-encoded values
# Format matches ExternalSecret expectations: {"tls.crt": "<base64>", "tls.key": "<base64>"}
resource "aws_ssm_parameter" "ca" {
  name        = var.ssm_parameter_path
  description = "Root CA for ${var.ca_name} (cert-manager ClusterIssuer)"
  type        = "SecureString"

  value = jsonencode({
    "tls.crt" = base64encode(tls_self_signed_cert.ca.cert_pem)
    "tls.key" = base64encode(tls_private_key.ca.private_key_pem)
  })

  tags = {
    managed-by = "opentofu"
    purpose    = "pki"
    ca-name    = var.ca_name
  }

  lifecycle {
    # Prevent accidental destruction of PKI material
    prevent_destroy = true
  }
}

# Local backup for disaster recovery
# User copies this file to secure offline storage
resource "local_sensitive_file" "ca_backup" {
  filename = var.local_backup_path

  content = jsonencode({
    ca_name      = var.ca_name
    ssm_path     = var.ssm_parameter_path
    generated_at = timestamp()
    expires_at   = timeadd(timestamp(), "${var.validity_days * 24}h")
    "tls.crt"    = base64encode(tls_self_signed_cert.ca.cert_pem)
    "tls.key"    = base64encode(tls_private_key.ca.private_key_pem)
  })

  file_permission = "0600"
}
