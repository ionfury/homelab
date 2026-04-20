# Unifi Gateway DDNS (Cloudflare)

Configure the Unifi gateway to automatically update a Cloudflare DNS A record
with the WAN public IP. This is the anchor record that ExternalDNS CNAME records
point to.

## When to Use

- Initial setup of external gateway access
- After gateway replacement or factory reset
- When changing the DDNS hostname or Cloudflare zone

## Prerequisites

- Unifi gateway running UniFi OS 4.x+
- Cloudflare API token with `Zone:Read` + `DNS:Edit` permissions for `tomnowak.work`
  - Token stored at SSM: `/homelab/infrastructure/accounts/cloudflare/token`
- Cloudflare zone ID: (from `infrastructure/accounts.hcl`)

## Procedure

### 1. Access Gateway Settings

Navigate to: **Settings → Internet → WAN → Dynamic DNS**

### 2. Add DDNS Entry

| Field | Value |
|-------|-------|
| Service | Cloudflare |
| Hostname | `gw.external.tomnowak.work` |
| Username | (leave blank or enter zone ID) |
| Password | Cloudflare API token |
| Server | Cloudflare zone ID from `accounts.hcl` |

> Note: Field mapping varies by UniFi OS version. If "Service" doesn't list
> Cloudflare, use "custom" and set server to `api.cloudflare.com`.

### 3. Verify

Wait 1-2 minutes for the gateway to update Cloudflare, then:

```bash
nslookup gw.external.tomnowak.work
# Should resolve to your WAN public IP

curl -s https://api.cloudflare.com/client/v4/zones/<zone_id>/dns_records \
  -H "Authorization: Bearer <token>" | jq '.result[] | select(.name == "gw.external.tomnowak.work")'
```

## Why Not IaC?

The `filipowm/unifi` Terraform provider v1.0.0 does not include a
`unifi_dynamic_dns` resource. If the provider adds support in a future
version, migrate this to the `unifi-gateway` module in the global stack.
