terraform {
  required_providers {
    harvester = {
      source  = "harvester/harvester"
      version = "0.6.4"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "4.62.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.14.0"
    }
  }
}
