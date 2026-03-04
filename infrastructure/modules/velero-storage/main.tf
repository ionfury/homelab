# Velero backup storage infrastructure for all clusters
# This module provisions S3 buckets, IAM users, and SSM parameters for each cluster.
#
# Separate from longhorn-storage because they have different lifecycles:
# - Velero backups are self-contained snapshots safe for age-based expiration
# - Longhorn backups are incremental and share blocks (cannot use S3 lifecycle)
# - longhorn-storage will be deleted once Velero fully replaces Longhorn backups

# S3 buckets - one per cluster
resource "aws_s3_bucket" "velero_backup" {
  for_each = var.clusters
  bucket   = "homelab-velero-backup-${each.key}"

  tags = {
    managed-by = "opentofu"
    purpose    = "velero-backup"
    cluster    = each.key
  }
}

resource "aws_s3_bucket_versioning" "velero_backup" {
  for_each = var.clusters
  bucket   = aws_s3_bucket.velero_backup[each.key].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "velero_backup" {
  for_each = var.clusters
  bucket   = aws_s3_bucket.velero_backup[each.key].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "velero_backup" {
  for_each = var.clusters
  bucket   = aws_s3_bucket.velero_backup[each.key].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle rule - expire backups after 90 days
# Unlike Longhorn, Velero backups are self-contained tarballs. Deleting old
# objects does not corrupt newer backups, making age-based expiration safe.
resource "aws_s3_bucket_lifecycle_configuration" "velero_backup" {
  for_each = var.clusters
  bucket   = aws_s3_bucket.velero_backup[each.key].id

  rule {
    id     = "expire-old-backups"
    status = "Enabled"

    expiration {
      days = 90
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# IAM users - one per cluster for isolated access
resource "aws_iam_user" "velero_backup" {
  for_each = var.clusters
  name     = "velero-backup-${each.key}"

  tags = {
    managed-by = "opentofu"
    purpose    = "velero-backup"
    cluster    = each.key
  }
}

resource "aws_iam_access_key" "velero_backup" {
  for_each = var.clusters
  user     = aws_iam_user.velero_backup[each.key].name
}

resource "aws_iam_user_policy" "velero_backup" {
  for_each = var.clusters
  name     = "velero-backup-${each.key}"
  user     = aws_iam_user.velero_backup[each.key].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "VeleroBackupAccess"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ]
        Resource = [
          aws_s3_bucket.velero_backup[each.key].arn,
          "${aws_s3_bucket.velero_backup[each.key].arn}/*"
        ]
      }
    ]
  })
}

# SSM Parameters - store credentials at paths expected by Kubernetes ExternalSecrets
resource "aws_ssm_parameter" "access_key_id" {
  for_each = var.clusters

  name        = "/homelab/kubernetes/${each.key}/velero-s3-backup/access-key-id"
  description = "AWS access key ID for Velero S3 backup in cluster '${each.key}'."
  type        = "SecureString"
  value       = aws_iam_access_key.velero_backup[each.key].id

  tags = {
    managed-by = "opentofu"
    purpose    = "velero-backup"
    cluster    = each.key
  }
}

resource "aws_ssm_parameter" "secret_access_key" {
  for_each = var.clusters

  name        = "/homelab/kubernetes/${each.key}/velero-s3-backup/secret-access-key"
  description = "AWS secret access key for Velero S3 backup in cluster '${each.key}'."
  type        = "SecureString"
  value       = aws_iam_access_key.velero_backup[each.key].secret

  tags = {
    managed-by = "opentofu"
    purpose    = "velero-backup"
    cluster    = each.key
  }
}
