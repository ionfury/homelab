# Public traffic enters through a router port-forward and DDNS

Public hostnames are CNAMEs to a DDNS record that follows the WAN IP, and the router forwards 80/443 to the external gateway. Cloudflare Tunnel and Tailscale were used before and dropped: the local environment is trusted, we want fewer cloud dependencies and real experience hosting ingress, and the load is low.
