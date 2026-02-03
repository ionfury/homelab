# Longhorn Disaster Recovery

Complete cluster recovery from S3 backups when all data is lost.

## Prerequisites

- AWS CLI configured with SSM Parameter Store access
- `talosctl`, `kubectl`, `flux` CLI tools installed (via `brew bundle`)
- Access to this git repository

## Destroy Behavior

When destroying a cluster with `task tg:destroy-<cluster>`, disks are **fully wiped by default**.
This ensures clean partition layouts on rebuild, preventing issues like undersized Longhorn volumes
caused by stale partitions from previous installations.

**Default wipe behavior:**
- `system_labels_to_wipe`: STATE, EPHEMERAL (Talos system partitions)
- `user_disks_to_wipe`: system_disk (wipes user volumes like u-longhorn)

**To preserve local replica data** (rarely needed since K8s metadata is lost anyway):

Edit the stack's `terragrunt.stack.hcl` to disable wipe:

```hcl
locals {
  on_destroy = {
    graceful              = false
    reboot                = true
    reset                 = true
    system_labels_to_wipe = []  # Empty = no system partition wipe
    user_disks_to_wipe    = []  # Empty = no user disk wipe
  }
}
```

> **Note:** Even with preserved local data, volumes must still be restored from S3 backups
> because PVC/Volume metadata is stored in etcd (which is always wiped).

## Indication

Use this runbook when:
- Complete cluster loss (all nodes failed)
- Longhorn storage corruption
- Need to restore volumes from S3 backup

## Remediation

### Step 1: Rebuild Cluster Infrastructure

```bash
# Requires human approval
task tg:apply-<cluster>
```

This provisions bare metal → Talos OS → Kubernetes → Flux bootstrap.

### Step 2: Retrieve Kubeconfig

```bash
aws ssm get-parameter \
  --name "/homelab/kubernetes/<cluster>/kubeconfig" \
  --with-decryption \
  --query "Parameter.Value" \
  --output text > ~/.kube/<cluster>.yaml
```

### Step 3: Wait for Flux Reconciliation

```bash
KUBECONFIG=~/.kube/<cluster>.yaml flux get kustomizations --watch
```

Wait until all kustomizations show `Ready: True`.

### Step 4: Verify S3 Backup Discovery

```bash
KUBECONFIG=~/.kube/<cluster>.yaml kubectl -n longhorn-system get backupvolumes
```

Longhorn automatically discovers backups from the configured S3 target.

### Step 5: Restore Volumes

**Option A: Via Longhorn UI**
1. Navigate to `https://longhorn.<internal_domain>`
2. Go to Backup tab
3. Select volume → Restore

**Option B: Via kubectl**
```bash
KUBECONFIG=~/.kube/<cluster>.yaml kubectl apply -f - <<EOF
apiVersion: longhorn.io/v1beta2
kind: Volume
metadata:
  name: <volume-name>
  namespace: longhorn-system
spec:
  fromBackup: "s3://homelab-longhorn-backup-<cluster>@us-east-2/?backup=<backup-name>&volume=<volume-name>"
  numberOfReplicas: 3
EOF
```

### Step 6: Recreate PVCs

```bash
KUBECONFIG=~/.kube/<cluster>.yaml kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: <pvc-name>
  namespace: <app-namespace>
spec:
  storageClassName: longhorn
  volumeName: <volume-name>
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: <size>
EOF
```

### Step 7: Restart Workloads

```bash
KUBECONFIG=~/.kube/<cluster>.yaml kubectl rollout restart deployment/<app> -n <namespace>
```

## Verification

```bash
# Check backup target connectivity
KUBECONFIG=~/.kube/<cluster>.yaml kubectl -n longhorn-system get settings backup-target

# List available backups
KUBECONFIG=~/.kube/<cluster>.yaml kubectl -n longhorn-system get backups

# Verify restored volume health
KUBECONFIG=~/.kube/<cluster>.yaml kubectl -n longhorn-system get volumes
```
