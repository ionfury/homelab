terraform {
  required_providers {
    harvester = {
      source  = "harvester/harvester"
      version = ">=0.6.4"
    }
    rancher2 = {
      source  = "rancher/rancher2"
      version = "3.1.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.14.0"
    }
    healthchecksio = {
      source  = "kristofferahl/healthchecksio"
      version = ">= 1.10.0"
    }
    flux = {
      source  = "fluxcd/flux"
      version = "1.0.1"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "4.23.0"
    }
  }
}
