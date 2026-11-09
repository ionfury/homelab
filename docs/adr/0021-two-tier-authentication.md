# Two-tier authentication: oauth2-proxy for admin UIs, Authelia for user apps

Platform and admin UIs sit behind oauth2-proxy (GitHub OAuth), called by the internal gateway through Istio external authorization. User-facing apps authenticate with OIDC against Authelia backed by LLDAP. Istio allows only one custom authorization provider per gateway, so Authelia forward-auth is not added to the internal gateway.
