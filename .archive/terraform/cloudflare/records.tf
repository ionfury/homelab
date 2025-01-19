/*
resource "cloudflare_record" "apex" {
  name    = "ipv4"
  zone_id = data.cloudflare_zone.domain.id
  value   = chomp(data.http.ipv4_lookup_raw.response_body)
  proxied = true
  type    = "A"
  ttl     = 1
}

resource "cloudflare_record" "root" {
  name    = var.tld
  zone_id = data.cloudflare_zone.domain.id
  value   = "ipv4.${var.tld}"
  proxied = true
  type    = "CNAME"
  ttl     = 1
}
*/
