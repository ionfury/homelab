terraform {
  required_providers {
    rancher2 = {
      source  = "rancher/rancher2"
      version = ">=2.0.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">=4.62.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.4.0"
    }
    harvester = {
      source  = "harvester/harvester"
      version = ">=0.6.2"
    }
  }
}
