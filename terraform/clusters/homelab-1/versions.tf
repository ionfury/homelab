terraform {
  required_providers {
    harvester = {
      source  = "harvester/harvester"
      version = ">=0.6.3"
    }
    rancher2 = {
      source  = "rancher/rancher2"
      version = "3.1.0"
    }
    healthchecksio = {
      source  = "kristofferahl/healthchecksio"
      version = ">= 1.10.0"
    }
    flux = {
      source  = "fluxcd/flux"
      version = "1.0.1"
    }
  }
}
