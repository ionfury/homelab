terraform {
  required_providers {
    harvester = {
      source  = "harvester/harvester"
      version = ">=0.6.2"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">=4.62.0"
    }
  }
}
