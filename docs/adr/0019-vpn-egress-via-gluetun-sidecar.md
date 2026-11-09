# VPN egress is a per-pod Gluetun sidecar, not Cilium EgressGateway

Workloads that must egress through a VPN run a Gluetun sidecar and are opted out of the mesh. Cilium EgressGateway requires `bpf.masquerade`, which breaks Istio Ambient, so cluster-level egress gateways are not used.
