provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

provider "harvester" {
  kubeconfig = "~/.kube/harvester"
}
