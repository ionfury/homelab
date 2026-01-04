terraform {
  required_version = ">= 1.8.8"
  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = "0.9.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.5"
    }
    time = {
      source  = "hashicorp/time"
      version = "0.12.1"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.3"
    }
  }
}
