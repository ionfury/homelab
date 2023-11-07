provider "aws" {
  region  = var.aws.region
  profile = var.aws.profile
}

data "aws_ssm_parameter" "cloudflare_api_key" {
  name = var.cloudflare_api_key_store
}

provider "cloudflare" {
  email   = var.master_email
  api_key = data.aws_ssm_parameter.cloudflare_api_key.value
}
