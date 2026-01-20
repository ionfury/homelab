# Network Policy Escape Hatch

This runbook covers the emergency procedure for disabling network policy enforcement when it blocks legitimate traffic.

## When to Use

- Application is experiencing connectivity issues
- Hubble shows traffic being dropped
- Immediate recovery is needed before root cause analysis

## Escape Hatch Procedure

### 1. Disable Enforcement

```bash
# Add the escape hatch label to the affected namespace
kubectl label namespace <namespace> network-policy.homelab/enforcement=disabled

# Verify the label is applied
kubectl get namespace <namespace> --show-labels
```

### 2. Verify Traffic Flows

```bash
# Check that traffic is no longer being dropped
hubble observe --namespace <namespace> --since 1m

# Verify application functionality
# (application-specific health checks)
```

### 3. Alert Acknowledgment

An alert will fire within 5 minutes:
- **NetworkPolicyEnforcementDisabled** (warning) - fires after 5 minutes
- **NetworkPolicyEnforcementDisabledLong** (critical) - fires after 24 hours

Acknowledge the alert and create a ticket to investigate the root cause.

## Root Cause Investigation

### 1. Collect Hubble Data

Before re-enabling enforcement, collect flow data to understand what traffic was blocked:

```bash
# Export flows while enforcement is disabled
hubble observe --namespace <namespace> --since 1h --output json > /tmp/<namespace>-flows.json

# Analyze unique destinations
cat /tmp/<namespace>-flows.json | \
  jq -r '.destination.namespace + "/" + (.destination.labels // {})["k8s:app.kubernetes.io/name"] + ":" + (.l4.TCP.destination_port // .l4.UDP.destination_port | tostring)' | \
  sort -u
```

### 2. Identify Missing Rules

Common causes:
- **Wrong profile**: Application needs `standard` but has `isolated`
- **Missing access label**: Application needs database but lacks `access.network-policy.homelab/postgres=true`
- **Missing port in baseline**: Application uses non-standard metrics port not in prometheus-scrape baseline
- **Missing K8s API access**: Application needs to talk to K8s API but namespace lacks `access.network-policy.homelab/kube-api=true`

### 3. Implement Fix

Based on root cause:

```bash
# Change profile
kubectl annotate namespace <namespace> network-policy.homelab/profile=standard --overwrite
kubectl label namespace <namespace> network-policy.homelab/profile=standard --overwrite

# Add shared resource access
kubectl label namespace <namespace> access.network-policy.homelab/postgres=true

# Add K8s API access
kubectl label namespace <namespace> access.network-policy.homelab/kube-api=true
```

### 4. Re-enable Enforcement

```bash
# Remove the escape hatch label
kubectl label namespace <namespace> network-policy.homelab/enforcement-

# Monitor for any new drops
hubble observe --namespace <namespace> --verdict DROPPED --since 5m
```

## GitOps Workflow

If the fix requires policy changes:

1. Create a PR with the policy updates
2. Test on integration cluster first
3. After merge, verify on live cluster
4. Document the incident and learnings

## Audit Trail

All escape hatch usage is auditable:

```bash
# Find namespaces with enforcement disabled
kubectl get namespaces -l network-policy.homelab/enforcement=disabled

# Check audit logs for who applied the label
# (requires Kubernetes audit logging to be enabled)
```

## Prevention

To prevent future incidents:
- Use discovery workflow for new applications (see [../plans/network-policy-architecture.md](../plans/network-policy-architecture.md))
- Review Hubble flows before enabling enforcement on new namespaces
- Test connectivity in integration cluster before promoting to live
