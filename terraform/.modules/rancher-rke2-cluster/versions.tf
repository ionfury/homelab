terraform {
  required_providers {
    rancher2 = {
      source = "rancher/rancher2"
      version = "2.0.0"
    }
    flux = {
      source = "fluxcd/flux"
      version = "1.0.0-rc.1"
    }
    local = {
      source = "hashicorp/local"
      version = "2.4.0"
    }
  }
}
