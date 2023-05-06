terraform {
  required_providers {
    harvester = {
      source  = "harvester/harvester"
      version = ">=0.6.2"
    }
    rke = {
      source  = "rancher/rke"
      version = ">=1.4.1"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">=3.4.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">=4.62.0"
    }
    github = {
      source  = "integrations/github"
      version = ">=5.23.0"
    }
    flux = {
      source  = "fluxcd/flux"
      version = "1.0.0-rc.1"
    }
  }
}
