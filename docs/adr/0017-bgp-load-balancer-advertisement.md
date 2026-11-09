# LoadBalancer IPs are advertised over BGP

Cilium advertises LoadBalancer IPs to the router over BGP, with a separate ASN per cluster, instead of L2 announcements. BGP gives real routed failover rather than relying on gratuitous ARP.
