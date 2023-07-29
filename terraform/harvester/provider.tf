provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

provider "harvester" {
  kubeconfig = var.harvester_kubeconfig_path
}

provider "kubectl" {
  config_path = var.harvester_kubeconfig_path
}
