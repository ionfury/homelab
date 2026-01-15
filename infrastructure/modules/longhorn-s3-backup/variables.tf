variable "cluster_name" {
  description = "Name of the cluster this backup bucket is for"
  type        = string
}

variable "region" {
  description = "AWS region for the S3 bucket"
  type        = string
  default     = "us-east-2"
}

variable "retention_days" {
  description = "Number of days to retain backup objects before expiration"
  type        = number
  default     = 90
}
