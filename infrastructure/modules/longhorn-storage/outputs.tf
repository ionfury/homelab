output "buckets" {
  description = "Map of cluster name to bucket details"
  value = {
    for cluster in var.clusters : cluster => {
      name   = aws_s3_bucket.longhorn_backup[cluster].id
      arn    = aws_s3_bucket.longhorn_backup[cluster].arn
      region = var.region
      target = "s3://${aws_s3_bucket.longhorn_backup[cluster].id}@${var.region}/"
    }
  }
}

output "ssm_parameters" {
  description = "Map of cluster name to SSM parameter paths"
  value = {
    for cluster in var.clusters : cluster => {
      access_key_id     = aws_ssm_parameter.access_key_id[cluster].name
      secret_access_key = aws_ssm_parameter.secret_access_key[cluster].name
    }
  }
}
