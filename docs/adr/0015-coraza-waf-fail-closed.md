# The WAF is Coraza as an Istio WasmPlugin on the external gateway, fail-closed

Internet traffic is filtered by Coraza (OWASP CRS) running as an Istio WasmPlugin on the external gateway only, as coarse HTTP hygiene rather than per-app access control. It fails closed: a WAF fault blocks public traffic, which was preferred over passing unfiltered traffic once services were exposed to the internet.
