# Generated by Terragrunt. Sig: nIlQXj57tbuaRZEa
terraform {
  backend "s3" {
    bucket         = "homelab-terragrunt-remote-state"
    dynamodb_table = "terragrunt"
    encrypt        = true
    key            = "clusters/dev-2/terraform.tfstate"
    profile        = "terragrunt"
    region         = "us-east-2"
  }
}
