provider "aws" {
  region  = var.aws.region
  profile = var.aws.profile
}

provider "harvester" {
  kubeconfig = var.harvester.kubeconfig_path
}

provider "kubectl" {
  config_path = var.harvester.kubeconfig_path
}
