terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">=2.9.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.14.0"
    }
    rancher2 = {
      source  = "rancher/rancher2"
      version = "3.2.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = ">=4.4.0"
    }
  }
}
