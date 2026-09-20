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

run "lifecycle_rules_scoped_to_velero_prefixes" {
  command = plan
  providers = {
    aws = aws.mock
  }

  variables {
    clusters = ["dev"]
    region   = "us-east-2"
  }

  assert {
    condition     = aws_s3_bucket_lifecycle_configuration.velero_backup["dev"].rule[0].filter[0].prefix == "backups/"
    error_message = "Backup metadata lifecycle rule must be scoped to backups/ prefix only"
  }

  assert {
    condition     = aws_s3_bucket_lifecycle_configuration.velero_backup["dev"].rule[1].filter[0].prefix == "restores/"
    error_message = "Restore metadata lifecycle rule must be scoped to restores/ prefix only"
  }

  assert {
    condition     = length([for r in aws_s3_bucket_lifecycle_configuration.velero_backup["dev"].rule : r if length(r.expiration) > 0 && r.filter[0].prefix == "kopia/"]) == 0
    error_message = "Kopia repository blobs must never be expired by lifecycle policy"
  }
}

run "transitions_kopia_blobs_to_cold_storage" {
  command = plan
  providers = {
    aws = aws.mock
  }

  variables {
    clusters = ["dev"]
    region   = "us-east-2"
  }

  assert {
    condition     = aws_s3_bucket_lifecycle_configuration.velero_backup["dev"].rule[2].filter[0].prefix == "kopia/"
    error_message = "Transition rule must be scoped to the kopia/ prefix"
  }

  assert {
    condition     = one(aws_s3_bucket_lifecycle_configuration.velero_backup["dev"].rule[2].transition).storage_class == "GLACIER_IR"
    error_message = "Kopia blobs should transition to Glacier Instant Retrieval, which Kopia can read without a restore job"
  }

  assert {
    condition     = one(aws_s3_bucket_lifecycle_configuration.velero_backup["dev"].rule[2].transition).days >= 30
    error_message = "Transition must wait at least 30 days so short-lived blobs do not incur the Glacier IR 90-day minimum charge"
  }
}

run "aborts_incomplete_multipart_uploads" {
  command = plan
  providers = {
    aws = aws.mock
  }

  variables {
    clusters = ["dev"]
    region   = "us-east-2"
  }

  assert {
    condition     = one(aws_s3_bucket_lifecycle_configuration.velero_backup["dev"].rule[3].abort_incomplete_multipart_upload).days_after_initiation == 7
    error_message = "Incomplete multipart uploads should be aborted after 7 days"
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
