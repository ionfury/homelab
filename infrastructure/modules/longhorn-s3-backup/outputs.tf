output "bucket_name" {
  description = "Name of the S3 bucket for Longhorn backups"
  value       = aws_s3_bucket.longhorn_backup.id
}

output "bucket_arn" {
  description = "ARN of the S3 bucket for Longhorn backups"
  value       = aws_s3_bucket.longhorn_backup.arn
}

output "bucket_region" {
  description = "Region of the S3 bucket"
  value       = var.region
}

output "access_key_id" {
  description = "AWS access key ID for Longhorn backup user"
  value       = aws_iam_access_key.longhorn_backup.id
  sensitive   = true
}

output "secret_access_key" {
  description = "AWS secret access key for Longhorn backup user"
  value       = aws_iam_access_key.longhorn_backup.secret
  sensitive   = true
}

output "backup_target" {
  description = "Longhorn backup target URL (s3://bucket@region/)"
  value       = "s3://${aws_s3_bucket.longhorn_backup.id}@${var.region}/"
}
