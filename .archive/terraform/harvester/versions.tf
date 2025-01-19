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
    flux = {
      source  = "fluxcd/flux"
      version = "1.0.1"
    }
    healthchecksio = {
      source  = "kristofferahl/healthchecksio"
      version = "1.10.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.25.2"
    }
  }
}
