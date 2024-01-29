resource "cloudflare_ruleset" "default" {
  kind    = "zone"
  name    = "default"
  phase   = "http_request_firewall_custom"
  zone_id = data.cloudflare_zone.domain.id
  rules {
    action = "skip"
    action_parameters {
      ruleset = "current"
    }
    description = "Allow GitHub flux API"
    enabled     = true
    expression  = "(http.host eq \"flux-webhook.tomnowak.work\" and ip.geoip.asnum eq 36459)"
    logging {
      enabled = true
    }
  }
  rules {
    action      = "block"
    description = "Firewall rule to block countries"
    enabled     = true
    expression  = "(ip.geoip.country in {\"CN\" \"IN\" \"KP\" \"RU\"})"
  }
  rules {
    action      = "block"
    description = "Firewall rule to block bots determined by CF"
    enabled     = true
    expression  = "(cf.client.bot) or (cf.threat_score gt 14)"
  }
}
