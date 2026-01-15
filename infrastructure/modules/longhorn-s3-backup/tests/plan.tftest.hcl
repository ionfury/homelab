# Plan tests for longhorn-s3-backup module - validates S3 bucket and IAM resources

mock_provider "aws" {
  alias = "mock"
}

run "basic_configuration" {
  command = plan
  providers = {
    aws = aws.mock
  }

  variables {
    cluster_name   = "dev"
    region         = "us-east-2"
    retention_days = 90
  }

  assert {
    condition     = aws_s3_bucket.longhorn_backup.bucket == "homelab-longhorn-backup-dev"
    error_message = "Bucket name should include cluster name"
  }

  assert {
    condition     = aws_s3_bucket.longhorn_backup.tags["managed-by"] == "terraform"
    error_message = "managed-by tag should be set to terraform"
  }

  assert {
    condition     = aws_s3_bucket.longhorn_backup.tags["purpose"] == "longhorn-backup"
    error_message = "purpose tag should be longhorn-backup"
  }

  assert {
    condition     = aws_s3_bucket.longhorn_backup.tags["cluster"] == "dev"
    error_message = "cluster tag should match cluster_name"
  }
}

run "versioning_enabled" {
  command = plan
  providers = {
    aws = aws.mock
  }

  variables {
    cluster_name = "integration"
  }

  assert {
    condition     = length(aws_s3_bucket_versioning.longhorn_backup.versioning_configuration) == 1
    error_message = "Versioning configuration should exist"
  }
}

run "encryption_configured" {
  command = plan
  providers = {
    aws = aws.mock
  }

  variables {
    cluster_name = "live"
  }

  assert {
    condition     = length(aws_s3_bucket_server_side_encryption_configuration.longhorn_backup.rule) == 1
    error_message = "Server-side encryption should have one rule"
  }
}

run "lifecycle_rules" {
  command = plan
  providers = {
    aws = aws.mock
  }

  variables {
    cluster_name   = "dev"
    retention_days = 30
  }

  assert {
    condition     = length(aws_s3_bucket_lifecycle_configuration.longhorn_backup.rule) == 1
    error_message = "Lifecycle configuration should have one rule"
  }
}

run "public_access_blocked" {
  command = plan
  providers = {
    aws = aws.mock
  }

  variables {
    cluster_name = "dev"
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.longhorn_backup.block_public_acls == true
    error_message = "Public ACLs should be blocked"
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.longhorn_backup.block_public_policy == true
    error_message = "Public policy should be blocked"
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.longhorn_backup.ignore_public_acls == true
    error_message = "Public ACLs should be ignored"
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.longhorn_backup.restrict_public_buckets == true
    error_message = "Public buckets should be restricted"
  }
}

run "iam_user_created" {
  command = plan
  providers = {
    aws = aws.mock
  }

  variables {
    cluster_name = "dev"
  }

  assert {
    condition     = aws_iam_user.longhorn_backup.name == "longhorn-backup-dev"
    error_message = "IAM user name should include cluster name"
  }

  assert {
    condition     = aws_iam_user.longhorn_backup.tags["managed-by"] == "terraform"
    error_message = "IAM user should have managed-by tag"
  }
}

run "iam_policy_permissions" {
  command = plan
  providers = {
    aws = aws.mock
  }

  variables {
    cluster_name = "dev"
  }

  assert {
    condition     = aws_iam_user_policy.longhorn_backup.name == "longhorn-backup-dev"
    error_message = "IAM policy name should include cluster name"
  }
}

run "outputs_generated" {
  command = plan
  providers = {
    aws = aws.mock
  }

  variables {
    cluster_name = "live"
    region       = "us-east-2"
  }

  # Note: bucket_name and backup_target use mock IDs, so we verify region instead
  assert {
    condition     = output.bucket_region == "us-east-2"
    error_message = "bucket_region output should match region variable"
  }

  # Verify outputs are not empty
  assert {
    condition     = output.bucket_name != ""
    error_message = "bucket_name output should not be empty"
  }

  assert {
    condition     = output.backup_target != ""
    error_message = "backup_target output should not be empty"
  }
}

run "different_clusters" {
  command = plan
  providers = {
    aws = aws.mock
  }

  variables {
    cluster_name = "integration"
  }

  assert {
    condition     = aws_s3_bucket.longhorn_backup.bucket == "homelab-longhorn-backup-integration"
    error_message = "Bucket should use integration cluster name"
  }

  assert {
    condition     = aws_iam_user.longhorn_backup.name == "longhorn-backup-integration"
    error_message = "IAM user should use integration cluster name"
  }
}
