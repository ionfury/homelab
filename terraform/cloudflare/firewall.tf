# Block Countries
resource "cloudflare_filter" "block_countries" {
  zone_id     = data.cloudflare_zone.domain.id
  description = "Expression to block countries"
  expression  = "(ip.geoip.country in {\"CN\" \"IN\" \"KP\" \"RU\"})"
}
resource "cloudflare_firewall_rule" "block_countries" {
  zone_id     = data.cloudflare_zone.domain.id
  description = "Firewall rule to block countries"
  filter_id   = cloudflare_filter.block_countries.id
  action      = "block"
}

# Block Bots
resource "cloudflare_filter" "bots" {
  zone_id     = data.cloudflare_zone.domain.id
  description = "Expression to block bots determined by CF"
  expression  = "(cf.client.bot) or (cf.threat_score gt 14)"
}
resource "cloudflare_firewall_rule" "bots" {
  zone_id     = data.cloudflare_zone.domain.id
  description = "Firewall rule to block bots determined by CF"
  filter_id   = cloudflare_filter.bots.id
  action      = "block"
}

# Accept Flux Github Webhook
resource "cloudflare_filter" "domain_github_flux_webhook" {
  zone_id     = data.cloudflare_zone.domain.id
  description = "Allow GitHub flux API"
  expression  = "(http.host eq \"flux-webhook.${var.tld}\" and ip.geoip.asnum eq 36459)"
}
resource "cloudflare_firewall_rule" "domain_github_flux_webhook" {
  zone_id     = data.cloudflare_zone.domain.id
  description = "Allow GitHub flux API"
  filter_id   = cloudflare_filter.domain_github_flux_webhook.id
  action      = "allow"
}
