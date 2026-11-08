# Istio implements Gateway API for all ingress

All north-south HTTP goes through Kubernetes Gateway API resources implemented by Istio; ingress-nginx is retired and Cilium's Gateway API stays disabled even though Cilium is the CNI. Gateway API is the routing contract, and Istio is the implementation because the WAF and external authorization rely on Istio extensions.
