# S3 bucket for Longhorn backups with encryption and versioning
# Note: No lifecycle expiration - Longhorn backups are incremental and share block
# objects across backups. Age-based S3 expiration would delete blocks still
# referenced by newer backups, corrupting them. Retention is managed by Longhorn's
# RecurringJob `retain` field instead.

resource "aws_s3_bucket" "longhorn_backup" {
  bucket = "homelab-longhorn-backup-${var.cluster_name}"

  tags = {
    managed-by = "terraform"
    purpose    = "longhorn-backup"
    cluster    = var.cluster_name
  }
}

resource "aws_s3_bucket_versioning" "longhorn_backup" {
  bucket = aws_s3_bucket.longhorn_backup.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "longhorn_backup" {
  bucket = aws_s3_bucket.longhorn_backup.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "longhorn_backup" {
  bucket = aws_s3_bucket.longhorn_backup.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# IAM user for Longhorn to access the backup bucket
resource "aws_iam_user" "longhorn_backup" {
  name = "longhorn-backup-${var.cluster_name}"

  tags = {
    managed-by = "terraform"
    purpose    = "longhorn-backup"
    cluster    = var.cluster_name
  }
}

resource "aws_iam_access_key" "longhorn_backup" {
  user = aws_iam_user.longhorn_backup.name
}

resource "aws_iam_user_policy" "longhorn_backup" {
  name = "longhorn-backup-${var.cluster_name}"
  user = aws_iam_user.longhorn_backup.name

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
          aws_s3_bucket.longhorn_backup.arn,
          "${aws_s3_bucket.longhorn_backup.arn}/*"
        ]
      }
    ]
  })
}
