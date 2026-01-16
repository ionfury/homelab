variable "clusters" {
  description = "Set of cluster names to provision backup infrastructure for"
  type        = set(string)
}

variable "region" {
  description = "AWS region for S3 buckets"
  type        = string
  default     = "us-east-2"
}
