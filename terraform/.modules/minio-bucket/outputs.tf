output "bucket" {
  value = {
    id         = minio_s3_bucket.bucket.id
    access_key = random_password.access_key.result
    secret_key = random_password.secret_key.result

  }
  sensitive = true
}
