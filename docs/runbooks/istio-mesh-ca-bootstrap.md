# Istio Mesh CA Bootstrap

One-time procedure to generate and store the shared Istio mesh root CA in AWS SSM Parameter Store.

## When to Use

- **First-time setup**: Before deploying istio-csr to any cluster
- **CA rotation**: When rotating the mesh CA (requires cluster rebuild or careful coordination)
- **Recovery**: If the SSM parameter is accidentally deleted

## Prerequisites

- AWS CLI configured with appropriate permissions
- `openssl` installed
- Access to AWS SSM Parameter Store

## Procedure

### 1. Generate Root CA Certificate

```bash
# Create working directory
mkdir -p /tmp/istio-mesh-ca && cd /tmp/istio-mesh-ca

# Generate private key (ECDSA P-256)
openssl ecparam -name prime256v1 -genkey -noout -out ca.key

# Generate self-signed root CA certificate (10 year validity)
openssl req -x509 -new -nodes \
  -key ca.key \
  -sha256 \
  -days 3650 \
  -out ca.crt \
  -subj "/O=homelab/CN=istio-mesh-root-ca" \
  -addext "basicConstraints=critical,CA:TRUE" \
  -addext "keyUsage=critical,keyCertSign,cRLSign"

# Verify certificate
openssl x509 -in ca.crt -text -noout | head -20
```

### 2. Store in AWS SSM Parameter Store

```bash
# Create JSON payload
cat > ca-payload.json << EOF
{
  "tls.crt": "$(cat ca.crt | base64 -w0)",
  "tls.key": "$(cat ca.key | base64 -w0)"
}
EOF

# Store as SecureString in SSM
aws ssm put-parameter \
  --name "/homelab/kubernetes/shared/istio-mesh-ca" \
  --type "SecureString" \
  --value "$(cat ca-payload.json)" \
  --description "Shared Istio mesh root CA for mTLS (all clusters)" \
  --overwrite

# Verify storage
aws ssm get-parameter \
  --name "/homelab/kubernetes/shared/istio-mesh-ca" \
  --with-decryption \
  --query 'Parameter.Value' \
  --output text | jq -r '."tls.crt"' | base64 -d | openssl x509 -text -noout | head -10
```

### 3. Cleanup

```bash
# Securely delete local files
rm -rf /tmp/istio-mesh-ca
```

## Verification

After cluster deployment, verify the CA was pulled correctly:

```bash
# Check ExternalSecret status
kubectl -n cert-manager get externalsecret istio-mesh-root-ca

# Check the secret was created
kubectl -n cert-manager get secret istio-mesh-root-ca

# Verify CA ClusterIssuer is ready
kubectl get clusterissuer istio-mesh-ca

# Check istio-csr can issue certificates
kubectl get certificaterequests -n istio-system
```

## Troubleshooting

### ExternalSecret not syncing

```bash
# Check ExternalSecret status
kubectl -n cert-manager describe externalsecret istio-mesh-root-ca

# Check ClusterSecretStore
kubectl get clustersecretstore aws-ssm -o yaml
```

### CA ClusterIssuer not ready

```bash
# Check issuer status
kubectl describe clusterissuer istio-mesh-ca

# Verify secret has correct keys
kubectl -n cert-manager get secret istio-mesh-root-ca -o jsonpath='{.data}' | jq
```

## Security Considerations

- The root CA private key is stored encrypted in SSM using AWS KMS
- Access is controlled via IAM policies attached to the External Secrets Operator role
- The CA is shared across all clusters - compromise affects all clusters
- Consider rotating the CA periodically (requires coordinated cluster rebuilds)
