# Plan tests for app-secrets module - validates secret generation and SSM storage

mock_provider "aws" {
  alias = "mock"
}

run "generates_secrets" {
  command = plan
  providers = {
    aws = aws.mock
  }

  variables {
    name = "test-app"
    secrets = {
      SECRET_A = { length = 32, special = false }
      SECRET_B = { length = 64, special = true }
    }
    ssm_parameter_path = "/test/app-secrets"
    local_backup_path  = "/tmp/test-app-secrets.json"
  }

  assert {
    condition     = random_password.secrets["SECRET_A"].length == 32
    error_message = "SECRET_A should have length 32"
  }

  assert {
    condition     = random_password.secrets["SECRET_A"].special == false
    error_message = "SECRET_A should not use special characters"
  }

  assert {
    condition     = random_password.secrets["SECRET_B"].length == 64
    error_message = "SECRET_B should have length 64"
  }

  assert {
    condition     = random_password.secrets["SECRET_B"].special == true
    error_message = "SECRET_B should use special characters"
  }
}

run "stores_in_ssm" {
  command = plan
  providers = {
    aws = aws.mock
  }

  variables {
    name = "lldap"
    secrets = {
      LLDAP_JWT_SECRET = { length = 32, special = false }
      LLDAP_KEY_SEED   = { length = 32, special = false }
    }
    ssm_parameter_path = "/homelab/kubernetes/live/lldap-secrets"
    local_backup_path  = "/tmp/lldap-secrets.json"
  }

  assert {
    condition     = aws_ssm_parameter.secrets.name == "/homelab/kubernetes/live/lldap-secrets"
    error_message = "SSM parameter path should match input"
  }

  assert {
    condition     = aws_ssm_parameter.secrets.type == "SecureString"
    error_message = "SSM parameter should be SecureString type"
  }

  assert {
    condition     = aws_ssm_parameter.secrets.tags["managed-by"] == "opentofu"
    error_message = "managed-by tag should be opentofu"
  }

  assert {
    condition     = aws_ssm_parameter.secrets.tags["purpose"] == "app-secrets"
    error_message = "purpose tag should be app-secrets"
  }

  assert {
    condition     = aws_ssm_parameter.secrets.tags["app-name"] == "lldap"
    error_message = "app-name tag should match input"
  }
}

run "creates_local_backup" {
  command = plan
  providers = {
    aws = aws.mock
  }

  variables {
    name = "test-app"
    secrets = {
      SECRET_A = { length = 16, special = false }
    }
    ssm_parameter_path = "/test/secrets"
    local_backup_path  = "/tmp/test-backup.json"
  }

  assert {
    condition     = local_sensitive_file.secrets_backup.filename == "/tmp/test-backup.json"
    error_message = "Local backup path should match input"
  }

  assert {
    condition     = local_sensitive_file.secrets_backup.file_permission == "0600"
    error_message = "Backup file should have restricted permissions"
  }
}
