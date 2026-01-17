terraform {
  required_version = ">= 1.8.8"
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "3.1.0"
    }
    github = {
      source  = "integrations/github"
      version = "6.10.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.36.0"
    }
    healthchecksio = {
      source  = "kristofferahl/healthchecksio"
      version = "2.0.0"
    }
  }
}
