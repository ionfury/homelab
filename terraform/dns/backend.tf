# Generated by Terragrunt. Sig: nIlQXj57tbuaRZEa
terraform {
  backend "s3" {
    bucket         = "homelab-terragrunt-remote-state"
    dynamodb_table = "terragrunt"
    encrypt        = true
    key            = "dns/terraform.tfstate"
    profile        = "terragrunt"
    region         = "us-east-2"
  }
}
