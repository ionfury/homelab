terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "4.18.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "3.4.0"
    }
  }
}
