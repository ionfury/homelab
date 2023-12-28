terraform {
  required_providers {
    rancher2 = {
      source  = "rancher/rancher2"
      version = "3.1.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.14.0"
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
      version = "0.6.4"
    }
  }
}
