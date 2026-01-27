# Backup storage infrastructure for all clusters
# This module provisions S3 buckets, IAM users, and SSM parameters for:
# - Longhorn: Volume-level backups for stateful workloads
# - CloudNative-PG (CNPG): PostgreSQL database backups via Barman
#
# Separated from cluster lifecycle so backups persist through cluster rebuilds.
#
# Note: No lifecycle expiration - Longhorn backups are incremental and share block
# objects across backups. CNPG uses retentionPolicy for automatic pruning.
# Age-based S3 expiration would delete blocks still referenced by newer backups,
# corrupting them. Retention is managed by the applications themselves.

# S3 buckets - one per cluster
resource "aws_s3_bucket" "longhorn_backup" {
  for_each = var.clusters
  bucket   = "homelab-longhorn-backup-${each.key}"

  tags = {
    managed-by = "opentofu"
    purpose    = "longhorn-backup"
    cluster    = each.key
  }
}

resource "aws_s3_bucket_versioning" "longhorn_backup" {
  for_each = var.clusters
  bucket   = aws_s3_bucket.longhorn_backup[each.key].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "longhorn_backup" {
  for_each = var.clusters
  bucket   = aws_s3_bucket.longhorn_backup[each.key].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "longhorn_backup" {
  for_each = var.clusters
  bucket   = aws_s3_bucket.longhorn_backup[each.key].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# IAM users - one per cluster for isolated access
resource "aws_iam_user" "longhorn_backup" {
  for_each = var.clusters
  name     = "longhorn-backup-${each.key}"

  tags = {
    managed-by = "opentofu"
    purpose    = "longhorn-backup"
    cluster    = each.key
  }
}

resource "aws_iam_access_key" "longhorn_backup" {
  for_each = var.clusters
  user     = aws_iam_user.longhorn_backup[each.key].name
}

resource "aws_iam_user_policy" "longhorn_backup" {
  for_each = var.clusters
  name     = "longhorn-backup-${each.key}"
  user     = aws_iam_user.longhorn_backup[each.key].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "LonghornBackupAccess"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ]
        Resource = [
          aws_s3_bucket.longhorn_backup[each.key].arn,
          "${aws_s3_bucket.longhorn_backup[each.key].arn}/*"
        ]
      }
    ]
  })
}

# SSM Parameters - store credentials at paths expected by Kubernetes ExternalSecrets
resource "aws_ssm_parameter" "access_key_id" {
  for_each = var.clusters

  name        = "/homelab/kubernetes/${each.key}/longhorn-s3-backup/access-key-id"
  description = "AWS access key ID for Longhorn S3 backup in cluster '${each.key}'."
  type        = "SecureString"
  value       = aws_iam_access_key.longhorn_backup[each.key].id

  tags = {
    managed-by = "opentofu"
    purpose    = "longhorn-backup"
    cluster    = each.key
  }
}

resource "aws_ssm_parameter" "secret_access_key" {
  for_each = var.clusters

  name        = "/homelab/kubernetes/${each.key}/longhorn-s3-backup/secret-access-key"
  description = "AWS secret access key for Longhorn S3 backup in cluster '${each.key}'."
  type        = "SecureString"
  value       = aws_iam_access_key.longhorn_backup[each.key].secret

  tags = {
    managed-by = "opentofu"
    purpose    = "longhorn-backup"
    cluster    = each.key
  }
}

# =============================================================================
# CloudNative-PG (CNPG) Backup Infrastructure
# =============================================================================
# PostgreSQL backups using Barman to S3. Enables automatic recovery on cluster
# rebuild - CNPG's bootstrap.recovery will restore from latest backup if exists.

# S3 buckets - one per cluster for CNPG
resource "aws_s3_bucket" "cnpg_backup" {
  for_each = var.clusters
  bucket   = "homelab-cnpg-backup-${each.key}"

  tags = {
    managed-by = "opentofu"
    purpose    = "cnpg-backup"
    cluster    = each.key
  }
}

resource "aws_s3_bucket_versioning" "cnpg_backup" {
  for_each = var.clusters
  bucket   = aws_s3_bucket.cnpg_backup[each.key].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cnpg_backup" {
  for_each = var.clusters
  bucket   = aws_s3_bucket.cnpg_backup[each.key].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "cnpg_backup" {
  for_each = var.clusters
  bucket   = aws_s3_bucket.cnpg_backup[each.key].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# IAM users - one per cluster for isolated CNPG access
resource "aws_iam_user" "cnpg_backup" {
  for_each = var.clusters
  name     = "cnpg-backup-${each.key}"

  tags = {
    managed-by = "opentofu"
    purpose    = "cnpg-backup"
    cluster    = each.key
  }
}

resource "aws_iam_access_key" "cnpg_backup" {
  for_each = var.clusters
  user     = aws_iam_user.cnpg_backup[each.key].name
}

resource "aws_iam_user_policy" "cnpg_backup" {
  for_each = var.clusters
  name     = "cnpg-backup-${each.key}"
  user     = aws_iam_user.cnpg_backup[each.key].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CNPGBackupAccess"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ]
        Resource = [
          aws_s3_bucket.cnpg_backup[each.key].arn,
          "${aws_s3_bucket.cnpg_backup[each.key].arn}/*"
        ]
      }
    ]
  })
}

# SSM Parameters - store CNPG credentials at paths expected by Kubernetes ExternalSecrets
resource "aws_ssm_parameter" "cnpg_access_key_id" {
  for_each = var.clusters

  name        = "/homelab/kubernetes/${each.key}/cnpg-s3-backup/access-key-id"
  description = "AWS access key ID for CloudNative-PG S3 backup in cluster '${each.key}'."
  type        = "SecureString"
  value       = aws_iam_access_key.cnpg_backup[each.key].id

  tags = {
    managed-by = "opentofu"
    purpose    = "cnpg-backup"
    cluster    = each.key
  }
}

resource "aws_ssm_parameter" "cnpg_secret_access_key" {
  for_each = var.clusters

  name        = "/homelab/kubernetes/${each.key}/cnpg-s3-backup/secret-access-key"
  description = "AWS secret access key for CloudNative-PG S3 backup in cluster '${each.key}'."
  type        = "SecureString"
  value       = aws_iam_access_key.cnpg_backup[each.key].secret

  tags = {
    managed-by = "opentofu"
    purpose    = "cnpg-backup"
    cluster    = each.key
  }
}
