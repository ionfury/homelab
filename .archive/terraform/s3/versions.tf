terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.29.0"
    }
    minio = {
      source  = "aminueza/minio"
      version = "2.2.0"
    }
  }
}
