# Plan tests for velero-storage module - validates S3 buckets, IAM users, and SSM parameters

mock_provider "aws" {
  alias = "mock"
}

run "creates_s3_buckets" {
  command = plan
  providers = {
    aws = aws.mock
  }

  variables {
    clusters = ["dev", "live"]
    region   = "us-east-2"
  }

  assert {
    condition     = aws_s3_bucket.velero_backup["dev"].bucket == "homelab-velero-backup-dev"
    error_message = "Dev bucket name should match naming convention"
  }

  assert {
    condition     = aws_s3_bucket.velero_backup["live"].bucket == "homelab-velero-backup-live"
    error_message = "Live bucket name should match naming convention"
  }
}

run "creates_iam_users" {
  command = plan
  providers = {
    aws = aws.mock
  }

  variables {
    clusters = ["dev"]
    region   = "us-east-2"
  }

  assert {
    condition     = aws_iam_user.velero_backup["dev"].name == "velero-backup-dev"
    error_message = "IAM user name should match naming convention"
  }
}

run "stores_credentials_in_ssm" {
  command = plan
  providers = {
    aws = aws.mock
  }

  variables {
    clusters = ["dev"]
    region   = "us-east-2"
  }

  assert {
    condition     = aws_ssm_parameter.access_key_id["dev"].name == "/homelab/kubernetes/dev/velero-s3-backup/access-key-id"
    error_message = "SSM access key path should match convention"
  }

  assert {
    condition     = aws_ssm_parameter.secret_access_key["dev"].name == "/homelab/kubernetes/dev/velero-s3-backup/secret-access-key"
    error_message = "SSM secret key path should match convention"
  }

  assert {
    condition     = aws_ssm_parameter.access_key_id["dev"].type == "SecureString"
    error_message = "SSM parameters should be SecureString"
  }
}
