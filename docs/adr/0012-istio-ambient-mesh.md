# Istio in Ambient mode is the service mesh, on top of Cilium

The service mesh is Istio in Ambient mode (ztunnel and istio-cni, no sidecars), running on Cilium as the CNI. Ambient provides mesh mTLS and gateway-level L7 policy without per-pod sidecars; Cilium's own mesh and a sidecar-based Istio were the alternatives.
