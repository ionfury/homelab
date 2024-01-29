provider "aws" {
  region  = var.aws.region
  profile = var.aws.profile
}

data "aws_ssm_parameter" "cloudflare_api_key" {
  name = var.cloudflare.api_key_store
}

provider "cloudflare" {
  email   = var.cloudflare.email
  api_key = data.aws_ssm_parameter.cloudflare_api_key.value
}
