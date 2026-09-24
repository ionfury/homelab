# Unifi Gateway DDNS (Cloudflare) — Verification

The Unifi gateway maintains the Cloudflare A record `gw.<external_domain>`
(the anchor that ExternalDNS CNAME records point to) with the WAN public IP.

This is **fully declarative**: the `unifi_dynamic_dns` resource in
`infrastructure/modules/unifi-gateway/` (global stack) provisions the DDNS
entry. There is no manual UI configuration.

## DNS Chain

```
app.<external_domain>  CNAME → gw.<external_domain>  A → WAN public IP
   (ExternalDNS)                  (Unifi DDNS)          (never stored in code)
```

## When to Use This Runbook

- After `task tg:apply-global` changes the unifi-gateway unit
- After gateway replacement or factory reset (re-apply the global stack)
- When external services stop resolving

## Prerequisites

- Cloudflare API token with `Zone:Read` + `DNS:Edit` scoped to the external
  zone only, stored at SSM: `/homelab/infrastructure/accounts/cloudflare/token`
- UniFi OS Cloudflare DDNS field mapping (handled by the module):
  - `host_name` = full record name (e.g. `gw.ionfury.tv`)
  - `login` = Cloudflare zone name (e.g. `ionfury.tv`)
  - `password` = API token
  - `server` = empty (controller knows the endpoint)

## Verify

Wait 1-2 minutes after apply for the gateway to push the update, then:

```bash
nslookup gw.<external_domain> 1.1.1.1
```

Should resolve to the WAN public IP (compare with `curl -s ifconfig.me` from
inside the network).

Check the record via the Cloudflare API:

```bash
curl -s https://api.cloudflare.com/client/v4/zones/<zone_id>/dns_records \
  -H "Authorization: Bearer <token>" | jq '.result[] | select(.name | startswith("gw."))'
```

Zone ID lives in `infrastructure/accounts.hcl`.

## Troubleshooting

- **Record not updating**: check DDNS status in UniFi under
  Settings → Internet → WAN → Dynamic DNS (state is Terraform-managed;
  do not edit fields there — fix the module/unit instead).
- **401 from Cloudflare**: token expired or scope wrong; rotate the SSM
  parameter and re-run `task tg:apply-global`.
- **UniFi OS version quirks**: some UniFi OS releases changed the Cloudflare
  field mapping. If the entry shows an error state, validate the mapping on
  the dev stack before touching the global stack.
