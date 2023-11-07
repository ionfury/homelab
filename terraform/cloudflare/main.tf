data "cloudflare_zone" "domain" {
  name = var.tld
}

data "http" "ipv4_lookup_raw" {
  url = "http://ipv4.icanhazip.com"
}
