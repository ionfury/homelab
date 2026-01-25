# Plan tests for pki module - validates CA certificate generation and SSM storage

mock_provider "aws" {
  alias = "mock"
}

run "creates_ca_certificate" {
  command = plan
  providers = {
    aws = aws.mock
  }

  variables {
    ca_name = "test-ca"
    ca_subject = {
      organization = "test-org"
      common_name  = "test-ca-root"
    }
    validity_days      = 3650
    ssm_parameter_path = "/test/pki/ca"
    local_backup_path  = "/tmp/test-ca-backup.json"
  }

  assert {
    condition     = tls_private_key.ca.algorithm == "ECDSA"
    error_message = "Private key should use ECDSA algorithm"
  }

  assert {
    condition     = tls_private_key.ca.ecdsa_curve == "P256"
    error_message = "ECDSA curve should be P256"
  }

  assert {
    condition     = tls_self_signed_cert.ca.is_ca_certificate == true
    error_message = "Certificate should be a CA certificate"
  }

  assert {
    condition     = contains(tls_self_signed_cert.ca.allowed_uses, "cert_signing")
    error_message = "CA should be allowed to sign certificates"
  }

  assert {
    condition     = contains(tls_self_signed_cert.ca.allowed_uses, "crl_signing")
    error_message = "CA should be allowed to sign CRLs"
  }
}

run "stores_in_ssm" {
  command = plan
  providers = {
    aws = aws.mock
  }

  variables {
    ca_name = "istio-mesh"
    ca_subject = {
      organization = "homelab"
      common_name  = "istio-mesh-root-ca"
    }
    validity_days      = 3650
    ssm_parameter_path = "/homelab/kubernetes/shared/istio-mesh-ca"
    local_backup_path  = "/tmp/istio-mesh-ca-backup.json"
  }

  assert {
    condition     = aws_ssm_parameter.ca.name == "/homelab/kubernetes/shared/istio-mesh-ca"
    error_message = "SSM parameter path should match input"
  }

  assert {
    condition     = aws_ssm_parameter.ca.type == "SecureString"
    error_message = "SSM parameter should be SecureString type"
  }

  assert {
    condition     = aws_ssm_parameter.ca.tags["managed-by"] == "opentofu"
    error_message = "managed-by tag should be opentofu"
  }

  assert {
    condition     = aws_ssm_parameter.ca.tags["purpose"] == "pki"
    error_message = "purpose tag should be pki"
  }

  assert {
    condition     = aws_ssm_parameter.ca.tags["ca-name"] == "istio-mesh"
    error_message = "ca-name tag should match input"
  }
}

run "creates_local_backup" {
  command = plan
  providers = {
    aws = aws.mock
  }

  variables {
    ca_name = "test-ca"
    ca_subject = {
      organization = "test-org"
      common_name  = "test-ca-root"
    }
    validity_days      = 365
    ssm_parameter_path = "/test/pki/ca"
    local_backup_path  = "/tmp/test-backup.json"
  }

  assert {
    condition     = local_sensitive_file.ca_backup.filename == "/tmp/test-backup.json"
    error_message = "Local backup path should match input"
  }

  assert {
    condition     = local_sensitive_file.ca_backup.file_permission == "0600"
    error_message = "Backup file should have restricted permissions"
  }
}

run "respects_validity_period" {
  command = plan
  providers = {
    aws = aws.mock
  }

  variables {
    ca_name = "short-lived-ca"
    ca_subject = {
      organization = "test"
      common_name  = "short-ca"
    }
    validity_days      = 30
    ssm_parameter_path = "/test/short-ca"
    local_backup_path  = "/tmp/short-ca.json"
  }

  assert {
    condition     = tls_self_signed_cert.ca.validity_period_hours == 720
    error_message = "Validity should be 30 days (720 hours)"
  }
}
