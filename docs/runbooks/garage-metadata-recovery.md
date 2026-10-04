# Garage Metadata Recovery

Rebuild a Garage storage node's corrupted metadata database (LMDB) while keeping the node's identity. Garage keeps 3 copies of its metadata, so a node that loses its copy can rebuild it from the other two without a layout change or a data rebalance.

Tested on Garage v2.4.1 with garage-operator v0.7.8. The Garage image has no shell, so file operations use a temporary alpine pod and Garage commands run as `kubectl exec ... -- /garage <subcommand>`.

## Indication

- `garage-storage-N-0` is in `CrashLoopBackOff` with `panicked at src/block/manager.rs:148:14: Unable to open block_local_rc tree: DbError("LMDB: MDB_CORRUPTED: Located page was wrong type")`.
- `GarageClusterUnhealthy`, `GaragePartitionsDegraded`, `GarageStorageNodeDown` and `GarageBlockResyncErrors` are firing, and the cluster reports 2 of 3 nodes.
- The node's Longhorn volumes are healthy. The corruption is inside the database file, typically after the underlying Longhorn engine died mid-write. With `metadataFsync` off, that looks to LMDB exactly like a power loss.

## Choose the procedure

This runbook applies when the node's identity survived: `node_key` and `node_key.pub` are still present on the metadata volume and `status.nodeId` on its `GarageNode` is unchanged.

If the identity is lost, follow the operator's "Lost source identity" procedure in garage-operator v0.7.8 `docs/operations/maintenance-and-recovery.md`. That procedure uses the `garage.rajsingh.info/drain` and `garage.rajsingh.info/acknowledge-lost-source` annotations on the `GarageNode`, then `garage layout remove` and `garage layout apply`, then a full rebalance.

Deleting and recreating the `GarageNode` does not fix a corrupt database. The storage PVCs default to `Retain` and the node's finalizer hands the same claims to the recreated slot, so the new pod starts on the same corrupted file.

## Prerequisites

- `kubectl` access to the `garage` and `longhorn-system` namespaces
- The other two Garage nodes healthy. Do not start if a second node is degraded.

## Remediation

### Step 1: Confirm the cluster can lose node N

```bash
export N=<node-index>
kubectl -n garage get garagecluster garage -o jsonpath='{.status.health}{"\n"}'
kubectl -n longhorn-system get volumes.longhorn.io $(kubectl -n garage get pvc metadata-garage-$N -o jsonpath='{.spec.volumeName}') -o jsonpath='{.status.state} {.status.robustness}{"\n"}'
```

Expect `partitionsQuorum` 256 and `connectedNodes` 2, and the metadata volume `attached healthy`. If `partitionsQuorum` is below 256, stop.

### Step 2: Pause the operator for node N and stop it

```bash
kubectl -n garage patch garagenode garage-storage-$N --type=merge -p '{"spec":{"maintenance":{"suspended":true}}}'
kubectl -n garage scale statefulset garage-storage-$N --replicas=0
kubectl -n garage wait --for=delete pod/garage-storage-$N-0 --timeout=120s
kubectl -n garage get statefulset garage-storage-$N
```

The StatefulSet must stay at `0/0`. If it returns to 1, the pause is not being honoured; stop and scale it back. Flux does not own `GarageNode` objects, so no Flux suspend is needed.

### Step 3: Move the corrupted database aside

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: garage-meta-rescue
  namespace: garage
spec:
  restartPolicy: Never
  securityContext:
    runAsUser: 1000
    runAsGroup: 1000
    fsGroup: 1000
  containers:
    - name: rescue
      image: alpine:3.24.2
      command: ["sleep", "3600"]
      volumeMounts:
        - name: metadata
          mountPath: /mnt/metadata
  volumes:
    - name: metadata
      persistentVolumeClaim:
        claimName: metadata-garage-$N
EOF
kubectl -n garage wait --for=condition=Ready pod/garage-meta-rescue --timeout=180s
kubectl -n garage exec garage-meta-rescue -- sh -c 'cd /mnt/metadata && ls -la && mkdir -p rescue-$(date -u +%Y%m%d) && cp -a node_key node_key.pub cluster_layout rescue-$(date -u +%Y%m%d)/ && mv db.lmdb db.lmdb.corrupt-$(date -u +%Y%m%d) && ls -la'
```

The first listing must show `node_key`, `node_key.pub` and `cluster_layout`. If either key is missing, stop and switch to the lost-identity procedure.

If the listing shows a `snapshots/` directory with a snapshot taken before the corruption, restore it instead of rebuilding from peers. Only changes made after the snapshot then need to resync:

```bash
kubectl -n garage exec garage-meta-rescue -- sh -c 'cd /mnt/metadata && ls snapshots && cp -r snapshots/<snapshot-timestamp> db.lmdb && ls -la'
```

Then remove the pod:

```bash
kubectl -n garage delete pod garage-meta-rescue
```

### Step 4: Start node N and unpause the operator

```bash
kubectl -n garage scale statefulset garage-storage-$N --replicas=1
kubectl -n garage wait --for=condition=Ready pod/garage-storage-$N-0 --timeout=180s
kubectl -n garage logs garage-storage-$N-0 --tail=20
kubectl -n garage patch garagenode garage-storage-$N --type=merge -p '{"spec":{"maintenance":{"suspended":false}}}'
```

The log must show the same node ID as `status.nodeId` on the `GarageNode` and no panic. Garage creates an empty `db.lmdb` on startup when none exists.

### Step 5: Rebuild metadata from the other nodes

```bash
kubectl -n garage exec garage-storage-$N-0 -- /garage repair --yes tables
kubectl -n garage exec garage-storage-$N-0 -- /garage repair --yes block-rc
```

`tables` copies the metadata tables back from the other two nodes, and `block-rc` rebuilds `block_local_rc`, the block reference counts that were corrupted. Garage's own documentation runs the table repair on every node with `garage repair -a --yes tables`; running it on node N alone was sufficient on 2026-10-03.

### Step 6: Clear the other nodes' resync backlog

While node N was down, the other two nodes failed to copy blocks to it and put those blocks on an exponential retry schedule that can take hours to drain on its own. Retry them now:

```bash
for p in $(kubectl -n garage get pods -o name | grep garage-storage | grep -v "garage-storage-$N-0"); do kubectl -n garage exec ${p#pod/} -- /garage block retry-now --all; done
for p in $(kubectl -n garage get pods -o name | grep garage-storage); do kubectl -n garage exec ${p#pod/} -- /garage stats | grep -E 'resync queue|resync errors'; done
```

Repeat the second command until every node reports 0 for both.

## Verification

```bash
kubectl -n garage exec garage-storage-$N-0 -- /garage status
kubectl -n garage get garagecluster garage -o jsonpath='{.status.health}{"\n"}'
```

Expect all 3 nodes under HEALTHY NODES with node N still on its original ID, and `connectedNodes:3`, `healthy:true`, `partitionsAllOk:256`. The Garage alerts clear within minutes; `GarageBlockResyncErrors` clears once the backlog reaches 0.

## Rollback

Until Step 5 runs, the original database is still on the volume as `db.lmdb.corrupt-<date>`. Repeat Steps 2 and 3 with `mv db.lmdb.corrupt-<date> db.lmdb` to return to the starting state.

## Don'ts

- Do not touch the other two Garage nodes. Losing one of them while node N is down drops below quorum.
- Do not delete the PVCs, `node_key`, or the `GarageNode`.
- Do not merge `GarageCluster` config changes while a node is down. The operator rolls the storage pods to apply them.

## Prevention

[#1857](https://github.com/ionfury/homelab/pull/1857) sets `metadataFsync: true`, so metadata writes reach disk before they are acknowledged, and `metadataAutoSnapshotInterval: 6h`, so a local snapshot is available for the restore option in Step 3.

## Related

- [longhorn-rwx-xfs-corruption.md](longhorn-rwx-xfs-corruption.md): the 2026-10-03 repair after which node2's instance-manager died and corrupted this database
- Garage, Recovering from failures: <https://garagehq.deuxfleurs.fr/documentation/operations/recovering/>
