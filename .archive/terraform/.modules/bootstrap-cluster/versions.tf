terraform {
  required_providers {
    flux = {
      source  = "fluxcd/flux"
      version = "1.0.1"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">=4.62.0"
    }
    healthchecksio = {
      source  = "kristofferahl/healthchecksio"
      version = ">=1.10.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.25.2"
    }
  }
}
