terraform {
  required_providers {
    rancher2 = {
      source  = "rancher/rancher2"
      version = "2.0.0"
    }
    flux = {
      source  = "fluxcd/flux"
      version = "1.0.0-rc.1"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">=4.62.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.4.0"
    }
    healthchecksio = {
      source = "kristofferahl/healthchecksio"
      version = "1.10.1"
    }
  }
}
