# Network segmentation uses Cilium policies with an implicit default-deny

Segmentation is done with Cilium CCNPs and CNPs: baseline policies select every endpoint, which puts all pods into enforcement mode, and namespaces opt into traffic through profiles and access labels. There is deliberately no explicit deny policy, because Cilium deny rules override every allow rule and would break the model.
