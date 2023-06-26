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
    healthchecksio = {
      source = "kristofferahl/healthchecksio"
      version = "1.10.1"
    }
  }
}

data "aws_ssm_parameter" "cloudflare_api_key" {
  name = "cloudflare-api-key"
}

data "aws_ssm_parameter" "healthchecksio_api_key" {
  name = "healthchecksio-api-key"
}

data "aws_ssm_parameter" "github_token" {
  name = "github-token"
}

data "aws_ssm_parameter" "unifi_password" {
  name = "unifi-password"
}

// Configured via `~/.aws`
provider "aws" {
  region = "us-east-2"
  profile = "terragrunt"
}
provider "harvester" {
  kubeconfig = "~/git/personal/homelab/.kubeconfig/harvester.yaml"
}
provider "rke" {
  log_file = "rke_debug.log"
}
provider "github" {
  owner = "ionfury"
  token = "${data.aws_ssm_parameter.github_token.value}"
}
provider "cloudflare" {
  email = "ionfury@gmail.com"
  api_key = "${data.aws_ssm_parameter.cloudflare_api_key.value}"
}
provider "unifi" {
  api_url = "https://192.168.1.1"
  password = "${data.aws_ssm_parameter.unifi_password.value}"
  username = "terraform"
  allow_insecure = true
}
provider "healthchecksio" {
  api_key = "${data.aws_ssm_parameter.healthchecksio_api_key.value}"
}