# Longhorn PVC Disaster Recovery Exercise Plan

## Overview

This document defines the architecture for an automated Longhorn DR exercise that validates backup/restore capabilities by deploying a test workload, backing it up to S3, destroying the dev cluster, rebuilding it, and verifying data restoration.

### Execution Model

**Manually initiated, fully automated execution.** An operator explicitly starts the exercise via `task dr:exercise`, then all phases execute without further intervention. This model:
- Requires human intent to begin (no accidental cluster destruction)
- Auto-approve flags are acceptable within a manually-initiated workflow
- Provides clear audit trail of who initiated and when

### Goals

- **Validate backup integrity**: Prove that S3 backups contain restorable data
- **Exercise full DR path**: Test the complete destroy→rebuild→restore workflow
- **Fully automated execution**: Once initiated, no human intervention required
- **Repeatable verification**: Deterministic pass/fail outcome based on data validation
- **Backup-aware bootstrap**: Clusters automatically restore from backups by default
- **Leverage existing infrastructure**: Reuse existing tasks and platform patterns

### Non-Goals

- Testing live or integration clusters (dev-only scope)
- Performance benchmarking of backup/restore operations
- Multi-volume or complex application state (single PVC test)
- Backup retention policy validation

### Target Cluster

**dev cluster** (4 nodes: node46-48 + rpi4)

| Property | Value |
|----------|-------|
| Nodes | 3x Supermicro x86_64 + 1x RPi4 ARM64 |
| Longhorn replicas | 3 |
| S3 bucket | `homelab-longhorn-backup-dev` |
| Storage class | `longhorn` (default) |

---

## Design Decisions

These decisions were made during planning and guide the implementation:

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Execution model | **Manually initiated** | Human explicitly starts exercise; auto-approve acceptable within manual workflow |
| Terragrunt auto-approve | Add flag support to existing tasks | Consistent interface; safe because exercise is manually initiated |
| Kubeconfig refresh | Create dedicated `k8s:get-kubeconfig` task | Reusable across other automation |
| Volume restore strategy | **Backup-aware bootstrap** with well-known PVC names | Clusters self-heal by default; opt-out for fresh starts |
| Failure handling | Require full re-run | Keep it simple; exercise is ~30 minutes |

---

## Architecture

### Backup-Aware Bootstrap (Major Change)

**Problem**: Currently, PVCs get random names (`pvc-<uuid>`) which makes backup restoration manual. After cluster rebuild, Longhorn discovers backups but doesn't know which PVCs should restore from them.

**Solution**: Use well-known, static PVC names and a volume restore orchestrator that runs early in cluster bootstrap.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Backup-Aware Bootstrap Architecture                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   Cluster Rebuild                                                           │
│        │                                                                    │
│        ▼                                                                    │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │  Longhorn Deployed (via Flux)                                       │   │
│   │  • S3 backup target configured                                      │   │
│   │  • Discovers existing backups in S3                                 │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│        │                                                                    │
│        ▼                                                                    │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │  Volume Restore Orchestrator (NEW)                                  │   │
│   │  • Runs as Flux pre-requisite (before workload kustomizations)      │   │
│   │  • Scans BackupVolumes for well-known volume names                  │   │
│   │  • Creates Longhorn Volume CRs with fromBackup for each match       │   │
│   │  • Skipped if SKIP_RESTORE=true annotation present                  │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│        │                                                                    │
│        ▼                                                                    │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │  Workload Kustomizations (via Flux)                                 │   │
│   │  • PVCs with well-known names bind to pre-restored volumes          │   │
│   │  • If no backup existed, fresh volumes created as normal            │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Well-Known Volume Naming Convention**:

| Resource | Naming Pattern | Example |
|----------|----------------|---------|
| PVC | `<app>-<purpose>` | `dr-exercise-data`, `postgres-data`, `grafana-data` |
| Longhorn Volume | Same as PVC name | `dr-exercise-data` |
| Backup Volume | Indexed by volume name | Discovered via `kubectl get backupvolumes` |

**Skip Restore Flag**:

For fresh deployments (no backup restoration), set cluster-level annotation:

```yaml
# In cluster-specific kustomization patch
metadata:
  annotations:
    longhorn.io/skip-backup-restore: "true"
```

### Exercise Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         DR Exercise Pipeline                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   Phase 1: Setup              Phase 2: Backup           Phase 3: Destroy   │
│   ─────────────────           ──────────────────        ─────────────────   │
│   • Fetch kubeconfig          • Trigger on-demand       • Verify backup     │
│   • Wait for cluster ready      backup via Longhorn       completed         │
│   • Deploy dr-exercise app      Backup CR               • Store checksum    │
│   • Write sentinel file       • Poll until backup         locally           │
│     to PVC                      state = Completed       • Destroy cluster   │
│   • Verify file exists                                    via terragrunt    │
│                                                                             │
│   Phase 4: Rebuild            Phase 5: Validate                             │
│   ─────────────────           ──────────────────                            │
│   • Apply cluster via         • Fetch new kubeconfig                        │
│     terragrunt                • Wait for Flux + Longhorn                    │
│   • Cluster bootstraps with   • Volume auto-restored via orchestrator       │
│     backup-aware restore      • Verify sentinel checksum                    │
│                               • Report pass/fail                            │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Key Simplification**: With backup-aware bootstrap, Phase 5 no longer needs manual volume restoration. The orchestrator handles it automatically during cluster rebuild.

### Test Workload Design

A dedicated `dr-exercise` app deployed via the platform that:
1. Uses a **well-known PVC name** (`dr-exercise-data`)
2. Mounts PVC to `/data`
3. Runs as a simple deployment (sleep infinity) to keep PVC bound
4. Can be triggered to write/verify via exec commands

```
┌─────────────────────────────────────────────────────────────────────┐
│  Namespace: dr-exercise                                             │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  Deployment: dr-exercise                                     │   │
│  │                                                              │   │
│  │  Container: busybox                                          │   │
│  │  Command: sleep infinity                                     │   │
│  │                                                              │   │
│  │  ┌─────────────────┐                                        │   │
│  │  │  Volume Mount   │                                        │   │
│  │  │  /data          │──────┐                                 │   │
│  │  └─────────────────┘      │                                 │   │
│  └───────────────────────────┼──────────────────────────────────┘   │
│                              │                                      │
│  ┌───────────────────────────▼──────────────────────────────────┐   │
│  │  PVC: dr-exercise-data (1Gi, RWO, longhorn)                   │   │
│  │                                                              │   │
│  │  Well-known name enables automatic backup restoration        │   │
│  │                                                              │   │
│  │  Labels:                                                     │   │
│  │    recurring-job-group.longhorn.io/backup-daily: enabled     │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Sentinel File Strategy

The exercise writes a deterministic sentinel file that can be verified after restore:

```bash
# Write sentinel (Phase 1)
TIMESTAMP=$(date -u +%Y%m%d%H%M%S)
CONTENT="DR-EXERCISE-${TIMESTAMP}-$(uuidgen)"
echo "${CONTENT}" > /data/sentinel.txt
sha256sum /data/sentinel.txt > /data/sentinel.sha256

# Verify sentinel (Phase 5)
sha256sum -c /data/sentinel.sha256
```

The checksum is stored both:
1. In the PVC (survives backup/restore)
2. In a local file (survives cluster destroy)

---

## Implementation Details

### File Structure

```
kubernetes/platform/
├── config/
│   ├── dr-exercise/                        # NEW: Test workload resources
│   │   ├── kustomization.yaml
│   │   ├── namespace.yaml
│   │   ├── deployment.yaml
│   │   └── pvc.yaml
│   └── longhorn/
│       └── restore-orchestrator/           # NEW: Backup-aware bootstrap
│           ├── kustomization.yaml
│           ├── serviceaccount.yaml
│           ├── role.yaml
│           ├── rolebinding.yaml
│           └── job.yaml
├── config.yaml                             # Add dr-exercise + orchestrator
└── helm-charts.yaml                        # Add orchestrator dependency

.taskfiles/
├── dr-exercise/                            # NEW: DR exercise tasks
│   └── taskfile.yaml
├── kubernetes/                             # MODIFY: Add kubeconfig task
│   └── taskfile.yaml
└── terragrunt/                             # MODIFY: Add flag passthrough
    └── taskfile.yaml
```

### Volume Restore Orchestrator

A Kubernetes Job that runs early in cluster bootstrap. **Key design notes:**

1. **Flux CD v2 ordering**: Use Kustomization `dependsOn` (not Weave v1 annotations)
2. **Query BackupVolumes**: These are auto-discovered from S3, not `Backup` CRs
3. **GitOps exception**: The Job creates Volume CRs dynamically because backup URLs aren't known at git-commit time

**Flux Kustomization ordering (in cluster kustomization.yaml):**
```yaml
# Ensure orchestrator runs after Longhorn but before workloads
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: longhorn-restore-orchestrator
  namespace: flux-system
spec:
  dependsOn:
    - name: longhorn  # Wait for Longhorn to discover S3 backups
  path: ./kubernetes/platform/config/longhorn/restore-orchestrator
  # ... other fields
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: workloads
  namespace: flux-system
spec:
  dependsOn:
    - name: longhorn-restore-orchestrator  # Wait for volumes to be restored
  # ... workload kustomizations
```

**Job (config/longhorn/restore-orchestrator/job.yaml):**
```yaml
# yaml-language-server: $schema=https://raw.githubusercontent.com/yannh/kubernetes-json-schema/master/v1.30.0/job-batch-v1.json
apiVersion: batch/v1
kind: Job
metadata:
  name: longhorn-restore-orchestrator
  namespace: longhorn-system
  labels:
    app.kubernetes.io/name: restore-orchestrator
    app.kubernetes.io/component: disaster-recovery
spec:
  ttlSecondsAfterFinished: 3600
  backoffLimit: 3
  template:
    spec:
      serviceAccountName: restore-orchestrator
      restartPolicy: OnFailure
      containers:
        - name: orchestrator
          image: bitnami/kubectl:1.31
          command:
            - /bin/bash
            - -c
            - |
              set -euo pipefail

              # Check for skip flag (for fresh deployments)
              SKIP=$(kubectl get configmap -n flux-system cluster-config \
                -o jsonpath='{.data.skip_backup_restore}' 2>/dev/null || echo "false")

              if [ "${SKIP}" = "true" ]; then
                echo "SKIP_BACKUP_RESTORE=true, skipping volume restoration"
                exit 0
              fi

              echo "Scanning for backup volumes to restore..."

              # Well-known volumes that should be restored from backup
              RESTORE_VOLUMES=(
                "dr-exercise-data"
                # Add other well-known volumes here as they're onboarded
              )

              for VOL_NAME in "${RESTORE_VOLUMES[@]}"; do
                echo "Checking for backup of ${VOL_NAME}..."

                # Query BackupVolume CR (auto-created when Longhorn discovers S3 backups)
                # BackupVolumes are named after the original volume name
                BACKUP_URL=$(kubectl -n longhorn-system get backupvolumes "${VOL_NAME}" \
                  -o jsonpath='{.status.lastBackupURL}' 2>/dev/null || echo "")

                if [ -z "${BACKUP_URL}" ]; then
                  echo "  No BackupVolume found for ${VOL_NAME}, will create fresh"
                  continue
                fi

                # Check if volume already exists
                if kubectl -n longhorn-system get volume "${VOL_NAME}" &>/dev/null; then
                  echo "  Volume ${VOL_NAME} already exists, skipping"
                  continue
                fi

                # NOTE: This kubectl apply is a GitOps exception. The backup URL
                # is dynamic (contains timestamps) and can't be known at git-commit time.
                # The Volume CR created here will be adopted by Flux on next reconcile.
                echo "  Restoring ${VOL_NAME} from ${BACKUP_URL}"
                kubectl apply -f - <<EOF
              apiVersion: longhorn.io/v1beta2
              kind: Volume
              metadata:
                name: ${VOL_NAME}
                namespace: longhorn-system
                labels:
                  app.kubernetes.io/managed-by: restore-orchestrator
              spec:
                fromBackup: "${BACKUP_URL}"
                numberOfReplicas: 3
                accessMode: rwo
              EOF

                # Wait for volume to be ready
                echo "  Waiting for volume restoration..."
                for i in $(seq 1 60); do
                  STATE=$(kubectl -n longhorn-system get volume "${VOL_NAME}" \
                    -o jsonpath='{.status.state}' 2>/dev/null || echo "")
                  if [ "${STATE}" = "detached" ] || [ "${STATE}" = "attached" ]; then
                    echo "  Volume ${VOL_NAME} restored successfully"
                    break
                  fi
                  sleep 5
                done
              done

              echo "Restore orchestration complete"
```

> **GitOps Exception Note**: The orchestrator uses `kubectl apply` to create Volume CRs because the backup URL contains dynamic timestamps that can't be predicted at git-commit time. This is an acceptable exception for disaster recovery scenarios where the goal is data restoration, not declarative state management.

### Platform Resources

**Namespace (config/dr-exercise/namespace.yaml):**
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: dr-exercise
  labels:
    purpose: disaster-recovery-testing
```

**PVC with Well-Known Name (config/dr-exercise/pvc.yaml):**
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: dr-exercise-data
  namespace: dr-exercise
  labels:
    recurring-job-group.longhorn.io/backup-daily: enabled
spec:
  storageClassName: longhorn
  volumeName: dr-exercise-data  # Bind to well-known volume name
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```

**Deployment (config/dr-exercise/deployment.yaml):**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dr-exercise
  namespace: dr-exercise
spec:
  replicas: 1
  selector:
    matchLabels:
      app: dr-exercise
  template:
    metadata:
      labels:
        app: dr-exercise
    spec:
      containers:
        - name: busybox
          image: busybox:1.36
          command: ["sleep", "infinity"]
          volumeMounts:
            - name: data
              mountPath: /data
          resources:
            limits:
              memory: 64Mi
              cpu: 100m
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: dr-exercise-data
```

### Taskfile: Kubeconfig Management

**New task in `.taskfiles/kubernetes/taskfile.yaml`:**
```yaml
tasks:
  get-kubeconfig:
    desc: Fetch kubeconfig from AWS SSM for a cluster
    vars:
      CLUSTER: '{{.CLUSTER | default "dev"}}'
      KUBECONFIG_PATH: '{{.KUBECONFIG_PATH | default "~/.kube/{{.CLUSTER}}.yaml"}}'
    cmds:
      - |
        aws ssm get-parameter \
          --name "/homelab/kubernetes/{{.CLUSTER}}/kubeconfig" \
          --with-decryption \
          --query "Parameter.Value" \
          --output text > {{.KUBECONFIG_PATH}}
        echo "Kubeconfig saved to {{.KUBECONFIG_PATH}}"
```

### Taskfile: Terragrunt Flag Support

**Modify `.taskfiles/terragrunt/taskfile.yaml` to pass CLI args:**
```yaml
tasks:
  apply-dev:
    desc: Apply dev cluster infrastructure
    cmds:
      - terragrunt run-all apply --terragrunt-working-dir infrastructure/stacks/dev {{.CLI_ARGS}}

  destroy-dev:
    desc: Destroy dev cluster infrastructure
    cmds:
      - terragrunt run-all destroy --terragrunt-working-dir infrastructure/stacks/dev {{.CLI_ARGS}}
```

Usage: `task tg:destroy-dev -- -auto-approve`

### Taskfile: DR Exercise

```yaml
# .taskfiles/dr-exercise/taskfile.yaml
version: "3"

vars:
  CLUSTER: dev
  NAMESPACE: dr-exercise
  PVC_NAME: dr-exercise-data
  DEPLOYMENT_NAME: dr-exercise
  KUBECONFIG: ~/.kube/{{.CLUSTER}}.yaml
  SENTINEL_FILE: /tmp/dr-exercise-sentinel-{{.CLUSTER}}.txt

tasks:
  exercise:
    desc: Run complete DR exercise (setup → backup → destroy → rebuild → verify)
    cmds:
      - task: pre-flight
      - task: setup
      - task: write-sentinel
      - task: trigger-backup
      - task: wait-backup
      - task: destroy-cluster
      - task: rebuild-cluster
      - task: wait-ready
      - task: verify-sentinel
      - task: report

  pre-flight:
    desc: Validate prerequisites
    cmds:
      - echo "=== DR Exercise Pre-flight Check ==="
      - command -v kubectl >/dev/null || (echo "kubectl not found" && exit 1)
      - command -v aws >/dev/null || (echo "aws cli not found" && exit 1)
      - command -v terragrunt >/dev/null || (echo "terragrunt not found" && exit 1)
      - echo "All prerequisites satisfied"

  setup:
    desc: Ensure dr-exercise workload is deployed and running
    cmds:
      - task: k8s:get-kubeconfig CLUSTER={{.CLUSTER}}
      - echo "Waiting for dr-exercise deployment..."
      - kubectl --kubeconfig {{.KUBECONFIG}} -n {{.NAMESPACE}} wait --for=condition=available deployment/{{.DEPLOYMENT_NAME}} --timeout=300s
      - echo "dr-exercise deployment ready"

  write-sentinel:
    desc: Write sentinel file to PVC with checksum
    cmds:
      - |
        TIMESTAMP=$(date -u +%Y%m%d%H%M%S)
        CONTENT="DR-EXERCISE-${TIMESTAMP}-$(uuidgen)"
        POD=$(kubectl --kubeconfig {{.KUBECONFIG}} -n {{.NAMESPACE}} get pod -l app={{.DEPLOYMENT_NAME}} -o jsonpath='{.items[0].metadata.name}')
        kubectl --kubeconfig {{.KUBECONFIG}} -n {{.NAMESPACE}} exec ${POD} -- sh -c "echo '${CONTENT}' > /data/sentinel.txt"
        CHECKSUM=$(kubectl --kubeconfig {{.KUBECONFIG}} -n {{.NAMESPACE}} exec ${POD} -- sha256sum /data/sentinel.txt | awk '{print $1}')
        echo "${CHECKSUM}" > {{.SENTINEL_FILE}}
        echo "Sentinel written. Checksum: ${CHECKSUM}"

  trigger-backup:
    desc: Create on-demand Longhorn backup (snapshot first, then backup)
    cmds:
      - |
        TIMESTAMP=$(date -u +%Y%m%d%H%M%S)
        SNAPSHOT_NAME="dr-exercise-snap-${TIMESTAMP}"
        BACKUP_NAME="dr-exercise-backup-${TIMESTAMP}"

        # Step 1: Create a snapshot of the volume
        # The volume name matches the PVC name due to well-known naming
        echo "Creating snapshot ${SNAPSHOT_NAME}..."
        kubectl --kubeconfig {{.KUBECONFIG}} apply -f - <<EOF
        apiVersion: longhorn.io/v1beta2
        kind: Snapshot
        metadata:
          name: ${SNAPSHOT_NAME}
          namespace: longhorn-system
        spec:
          volume: {{.PVC_NAME}}
          labels:
            dr-exercise: "true"
        EOF

        # Wait for snapshot to be ready
        echo "Waiting for snapshot to be ready..."
        for i in $(seq 1 30); do
          READY=$(kubectl --kubeconfig {{.KUBECONFIG}} -n longhorn-system get snapshot ${SNAPSHOT_NAME} \
            -o jsonpath='{.status.readyToUse}' 2>/dev/null || echo "false")
          if [ "${READY}" = "true" ]; then
            echo "Snapshot ready"
            break
          fi
          sleep 2
        done

        # Step 2: Create backup from the snapshot
        echo "Creating backup ${BACKUP_NAME} from snapshot..."
        kubectl --kubeconfig {{.KUBECONFIG}} apply -f - <<EOF
        apiVersion: longhorn.io/v1beta2
        kind: Backup
        metadata:
          name: ${BACKUP_NAME}
          namespace: longhorn-system
          labels:
            longhornvolume: {{.PVC_NAME}}
            dr-exercise: "true"
        spec:
          snapshotName: ${SNAPSHOT_NAME}
          labels:
            dr-exercise: "true"
            longhornvolume: {{.PVC_NAME}}
        EOF

        echo "Backup triggered: ${BACKUP_NAME}"
        echo "${BACKUP_NAME}" > /tmp/dr-exercise-backup-name.txt

  wait-backup:
    desc: Wait for backup to complete
    cmds:
      - |
        BACKUP_NAME=$(cat /tmp/dr-exercise-backup-name.txt)
        echo "Waiting for backup ${BACKUP_NAME} to complete..."
        for i in $(seq 1 60); do
          STATE=$(kubectl --kubeconfig {{.KUBECONFIG}} -n longhorn-system get backup ${BACKUP_NAME} -o jsonpath='{.status.state}' 2>/dev/null || echo "Pending")
          echo "  Attempt ${i}/60: State=${STATE}"
          if [ "${STATE}" = "Completed" ]; then
            echo "Backup completed successfully"
            exit 0
          fi
          if [ "${STATE}" = "Error" ]; then
            echo "Backup failed!"
            kubectl --kubeconfig {{.KUBECONFIG}} -n longhorn-system get backup ${BACKUP_NAME} -o yaml
            exit 1
          fi
          sleep 10
        done
        echo "Backup timed out"
        exit 1

  destroy-cluster:
    desc: Destroy dev cluster infrastructure
    cmds:
      - echo "=== Destroying dev cluster ==="
      - task tg:destroy-{{.CLUSTER}} -- -auto-approve
      - echo "Cluster destroyed"

  rebuild-cluster:
    desc: Rebuild dev cluster infrastructure
    cmds:
      - echo "=== Rebuilding dev cluster ==="
      - task tg:apply-{{.CLUSTER}} -- -auto-approve
      - echo "Cluster rebuild initiated"

  wait-ready:
    desc: Wait for cluster and Longhorn to be ready
    cmds:
      - task: k8s:get-kubeconfig CLUSTER={{.CLUSTER}}
      - |
        echo "Waiting for cluster API..."
        for i in $(seq 1 60); do
          if kubectl --kubeconfig {{.KUBECONFIG}} cluster-info &>/dev/null; then
            echo "Cluster API ready"
            break
          fi
          echo "  Attempt ${i}/60: Waiting..."
          sleep 10
        done
      - |
        echo "Waiting for Flux reconciliation..."
        kubectl --kubeconfig {{.KUBECONFIG}} wait --for=condition=Ready kustomization/flux-system -n flux-system --timeout=600s
      - |
        echo "Waiting for Longhorn..."
        kubectl --kubeconfig {{.KUBECONFIG}} -n longhorn-system wait --for=condition=available deployment/longhorn-driver-deployer --timeout=300s
      - |
        echo "Waiting for restore orchestrator to complete..."
        kubectl --kubeconfig {{.KUBECONFIG}} -n longhorn-system wait --for=condition=complete job/longhorn-restore-orchestrator --timeout=300s || true
      - |
        echo "Waiting for dr-exercise deployment..."
        kubectl --kubeconfig {{.KUBECONFIG}} -n {{.NAMESPACE}} wait --for=condition=available deployment/{{.DEPLOYMENT_NAME}} --timeout=300s

  verify-sentinel:
    desc: Verify sentinel file matches expected checksum
    cmds:
      - |
        EXPECTED_CHECKSUM=$(cat {{.SENTINEL_FILE}})
        POD=$(kubectl --kubeconfig {{.KUBECONFIG}} -n {{.NAMESPACE}} get pod -l app={{.DEPLOYMENT_NAME}} -o jsonpath='{.items[0].metadata.name}')
        ACTUAL_CHECKSUM=$(kubectl --kubeconfig {{.KUBECONFIG}} -n {{.NAMESPACE}} exec ${POD} -- sha256sum /data/sentinel.txt 2>/dev/null | awk '{print $1}')

        echo "Expected: ${EXPECTED_CHECKSUM}"
        echo "Actual:   ${ACTUAL_CHECKSUM}"

        if [ "${EXPECTED_CHECKSUM}" = "${ACTUAL_CHECKSUM}" ]; then
          echo "✅ DR Exercise PASSED: Sentinel file verified"
          exit 0
        else
          echo "❌ DR Exercise FAILED: Checksum mismatch"
          exit 1
        fi

  report:
    desc: Generate exercise report
    cmds:
      - |
        echo "=================================="
        echo "  DR Exercise Complete"
        echo "=================================="
        echo "Cluster: {{.CLUSTER}}"
        echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "Result: PASSED"
        echo "=================================="
```

---

## Implementation Phases

### Phase 1: Foundation (Tasks + Test App)

- [ ] Create `.taskfiles/dr-exercise/taskfile.yaml` with task skeleton
- [ ] Add `k8s:get-kubeconfig` task to `.taskfiles/kubernetes/taskfile.yaml`
- [ ] Add `{{.CLI_ARGS}}` support to terragrunt apply/destroy tasks
- [ ] Create `kubernetes/platform/config/dr-exercise/` resources
- [ ] Add dr-exercise to platform `config.yaml` ResourceSet
- [ ] Verify test app deploys correctly on dev cluster
- [ ] Verify PVC is created with well-known name

### Phase 2: Backup-Aware Bootstrap

- [ ] Create `kubernetes/platform/config/longhorn/restore-orchestrator/` resources
- [ ] Add restore orchestrator Job with RBAC
- [ ] Configure Flux dependency so orchestrator runs before workloads
- [ ] Add `skip_backup_restore` flag support
- [ ] Test orchestrator on manual cluster rebuild
- [ ] Verify PVC binds to pre-restored volume

### Phase 3: Backup Automation

- [ ] Implement `write-sentinel` task
- [ ] Implement `trigger-backup` task with proper labels
- [ ] Implement `wait-backup` task with polling
- [ ] Verify backup appears in S3 with correct metadata
- [ ] Verify backup is discoverable by volume name label

### Phase 4: Cluster Lifecycle

- [ ] Implement `destroy-cluster` task with auto-approve
- [ ] Implement `rebuild-cluster` task with auto-approve
- [ ] Test kubeconfig refresh after rebuild
- [ ] Verify cluster rebuilds with backup restoration

### Phase 5: Validation & Integration

- [ ] Implement `verify-sentinel` task with checksum comparison
- [ ] Implement `report` task with summary output
- [ ] Create main `exercise` task that orchestrates all phases
- [ ] Add timeout handling for each phase
- [ ] Test full end-to-end exercise
- [ ] Document recovery procedures if exercise fails mid-way

---

## Success Criteria

- Full exercise completes without manual intervention
- Sentinel file checksum matches after restore (data integrity verified)
- Volume automatically restored via orchestrator (no manual kubectl)
- Exercise completes in under 45 minutes (reasonable time for dev cluster)
- Cluster is fully functional after exercise (all workloads healthy)
- Clear pass/fail output with actionable error messages on failure

---

## Mid-Exercise Failure Recovery

If the DR exercise fails partway through, use these recovery procedures:

### Phase 1-2 Failure (Setup/Backup)

**Symptom:** Exercise fails before cluster destruction
**Recovery:** Safe to re-run the exercise from the beginning
```bash
# Re-run the full exercise
task dr:exercise
```

### Phase 3 Failure (Destroy Incomplete)

**Symptom:** Cluster partially destroyed, some resources remain
**Recovery:** Force complete destruction, then re-run
```bash
# Check what's left
task tg:plan-dev

# Force destroy with cleanup
task tg:destroy-dev -- -auto-approve

# If terragrunt is stuck, check for orphaned resources
aws ec2 describe-instances --filters "Name=tag:Cluster,Values=dev"

# After successful destroy, re-run exercise
task dr:exercise
```

### Phase 4 Failure (Rebuild Incomplete)

**Symptom:** Cluster partially rebuilt, Talos nodes stuck
**Recovery:** Retry apply, or full teardown and rebuild
```bash
# First, try to complete the apply
task tg:apply-dev -- -auto-approve

# If stuck, check Talos node status
talosctl --nodes <node-ip> health

# If nodes are unrecoverable, destroy and rebuild
task tg:destroy-dev -- -auto-approve
task tg:apply-dev -- -auto-approve
```

### Phase 5 Failure (Validation)

**Symptom:** Cluster rebuilt but sentinel verification fails
**Recovery:** Investigate why data wasn't restored

```bash
# Check if BackupVolume was discovered
kubectl -n longhorn-system get backupvolumes

# Check if restore orchestrator ran
kubectl -n longhorn-system logs job/longhorn-restore-orchestrator

# Check if volume was created from backup
kubectl -n longhorn-system get volumes dr-exercise-data -o yaml | grep fromBackup

# Check PVC binding
kubectl -n dr-exercise get pvc
```

---

## Kubernetes Taskfile

**File to create:** `.taskfiles/kubernetes/taskfile.yaml`

```yaml
version: "3"

tasks:
  get-kubeconfig:
    desc: Fetch kubeconfig from AWS SSM for a cluster
    vars:
      CLUSTER: '{{.CLUSTER | default "dev"}}'
      KUBECONFIG_PATH: '{{.KUBECONFIG_PATH | default "~/.kube/{{.CLUSTER}}.yaml"}}'
    cmds:
      - |
        set -euo pipefail
        echo "Fetching kubeconfig for cluster: {{.CLUSTER}}"
        aws ssm get-parameter \
          --name "/homelab/kubernetes/{{.CLUSTER}}/kubeconfig" \
          --with-decryption \
          --query "Parameter.Value" \
          --output text > {{.KUBECONFIG_PATH}}
        chmod 600 {{.KUBECONFIG_PATH}}
        echo "Kubeconfig saved to {{.KUBECONFIG_PATH}}"

  health:
    desc: Check cluster health
    vars:
      CLUSTER: '{{.CLUSTER | default "dev"}}'
      KUBECONFIG: '{{.KUBECONFIG | default "~/.kube/{{.CLUSTER}}.yaml"}}'
    cmds:
      - kubectl --kubeconfig {{.KUBECONFIG}} cluster-info
      - kubectl --kubeconfig {{.KUBECONFIG}} get nodes
      - kubectl --kubeconfig {{.KUBECONFIG}} get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded
```

---

## Risk Considerations

| Risk | Mitigation |
|------|------------|
| Dev cluster used during exercise | Document that dev cluster should be idle during DR exercise |
| S3 backup bucket accidentally deleted | Storage stack is separate from cluster stack, never destroyed |
| Restore orchestrator fails | Job has backoffLimit=3; failure doesn't block cluster, just skips restoration |
| Volume name collision | Orchestrator checks if volume exists before restoring |
| Backup metadata missing | Labels ensure backups are findable by volume name |

---

## Future Enhancements

After initial implementation:

1. **Scheduled execution**: Run exercise monthly via GitHub Actions
2. **Metrics collection**: Track exercise duration and success rate in Prometheus
3. **Multi-volume testing**: Expand RESTORE_VOLUMES list in orchestrator
4. **Integration cluster**: Port exercise to integration cluster for pre-prod validation
5. **Alerting**: Notify on exercise failure via Discord webhook
6. **Broader adoption**: Apply well-known PVC naming to all critical workloads (databases, etc.)
