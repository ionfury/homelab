terraform {
  required_providers {
    harvester = {
      source  = "harvester/harvester"
      version = ">=0.6.3"
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
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = ">=4.4.0"
    }
    rancher2 = {
      source  = "rancher/rancher2"
      version = "3.1.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.14.0"
    }
    unifi = {
      source  = "paultyng/unifi"
      version = "0.41.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.5.1"
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
