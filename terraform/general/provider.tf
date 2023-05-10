# Generated by Terragrunt. Sig: nIlQXj57tbuaRZEa
terraform {
  required_providers {
    harvester = {
      source  = "harvester/harvester"
      version = ">=0.6.2"
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
      source = "integrations/github"
      version = ">=5.23.0"
    }
    cloudflare = {
      source = "cloudflare/cloudflare"
      version = ">=4.4.0"
    }
    rancher2 = {
      source = "rancher/rancher2"
      version = "2.0.0"
    }
    unifi = {
      source = "paultyng/unifi"
      version = "0.41.0"
    }
  }
}

data "aws_ssm_parameter" "cloudflare_api_key" {
  name = "cloudflare-api-key"
}

provider "harvester" {
  kubeconfig = "~/git/personal/homelab/.kubeconfig/harvester.yaml"
}
// Configured via `~/.aws`
provider "aws" {
  region = "us-east-2"
  profile = "terragrunt"
}
provider "rke" {
  log_file = "rke_debug.log"
}
provider "github" {
  owner = "ionfury"
}
provider "cloudflare" {
  email = "ionfury@gmail.com"
  api_key = "${data.aws_ssm_parameter.cloudflare_api_key.value}"
}
provider "unifi" {
  # use UNIFI_USERNAME env var
  # use UNIFI_PASSWORD env var
  api_url = "https://192.168.1.1"
  allow_insecure = true
}
