# Two gateways: trusted internal and hardened external

The internal gateway serves the internal domain for trusted LAN traffic, with oauth2-proxy guarding admin UIs. The external gateway is the only internet-facing path and carries the WAF, rate limiting and security headers. Applications without SSO, and high-value targets such as Vaultwarden, get no external route.
