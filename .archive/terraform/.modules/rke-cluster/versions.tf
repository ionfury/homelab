terraform {
  required_providers {
    harvester = {
      source  = "harvester/harvester"
      version = ">=0.6.4"
    }
    rke = {
      source  = "rancher/rke"
      version = ">=1.4.1"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">=3.4.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.14.0"
    }
  }
}
