terraform {
  required_version = ">= 1.8.8"
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "3.2.0"
    }
    github = {
      source  = "integrations/github"
      version = "6.13.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.2.1"
    }
    healthchecksio = {
      source  = "kristofferahl/healthchecksio"
      version = "2.3.0"
    }
  }
}
