terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">=4.62.0"
    }
    unifi = {
      source  = "paultyng/unifi"
      version = "0.41.0"
    }
  }
}
