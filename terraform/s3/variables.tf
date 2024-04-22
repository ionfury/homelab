variable "minio" {
  type = object({
    password_store = string
    buckets        = list(string)
  })
}
