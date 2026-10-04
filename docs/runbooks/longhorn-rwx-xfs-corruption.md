# Longhorn RWX Volume XFS Corruption

Repair the XFS filesystem inside a Longhorn RWX (ReadWriteMany) volume after an unclean shutdown corrupted its journal, for example a node drain or reboot that killed the volume's engine while its share-manager had the filesystem mounted. The procedure attaches the raw block device without the share-manager, checks it read-only, then runs `xfs_repair -L`.

Commands assume zsh. zsh does not word-split unquoted variables, so consumer lists must be arrays (`APPS=(sonarr radarr)`). A space-separated string (`APPS="sonarr radarr"`) is passed to `flux` and `kubectl` as a single argument.

## Indication

- Every pod mounting the volume is stuck in `ContainerCreating` with `FailedAttachVolume ... Waiting for volume share to be available`.
- The volume's `sharemanagers.longhorn.io` object sits in `state: starting`.
- A `share-manager-<vol>` pod is created, fails within about 3 seconds, and is deleted and recreated every 2 minutes. Its restart count stays at 0 because each attempt is a new pod.
- The share-manager pod log shows `mount: /export/<vol>: mount system call failed: Structure needs cleaning` and exits with status 32.
- `talosctl -n <node-ip> dmesg` on the engine node shows `XFS (sdX): Corruption detected. Unmount and run xfs_repair` and `log mount/recovery failed: error -117`.
- The Longhorn volume itself reports `attached` and `robustness: healthy`. The damage is inside the filesystem, not in the replicas.
- Pods that mounted the share before it failed can still report Ready while their NFS mount hangs. `ls` on the mount path never returns.
- `LonghornVolumeAttachmentStuck` fires after 30 minutes.

## Prerequisites

- `kubectl` and `flux` access to the cluster, and `talosctl` for the engine node's kernel log
- A window where every workload using the volume can be stopped

## Remediation

### Step 1: Record the volume details

```bash
export VOL=<longhorn-volume-name>
kubectl -n longhorn-system get volumes.longhorn.io $VOL -o jsonpath='{.status.currentNodeID} {.status.kubernetesStatus.namespace}{"\n"}'
kubectl -n longhorn-system get volumes.longhorn.io $VOL -o jsonpath='{.status.kubernetesStatus.workloadsStatus}' | jq -r '.[].workloadName'
```

The first command prints the engine node and the consumers' namespace. The second lists every workload that references the volume, including pods that are Pending.

### Step 2: Stop every consumer

```bash
APPS=(<app-1> <app-2>)
NS=<namespace>
for a in $APPS; do flux -n flux-system suspend helmrelease $a; done
for a in $APPS; do kubectl -n $NS scale deploy $a --replicas=0; done
flux -n flux-system get helmreleases | grep -E "${(j:|:)APPS}"
kubectl -n $NS get pods | grep -E "^(${(j:|:)APPS})-"
```

Every listed HelmRelease must show `SUSPENDED True`, and no consumer pods may remain. A pod with a hung NFS mount can take a minute or two to terminate.

### Step 3: Wait for Longhorn to fully detach

```bash
kubectl -n longhorn-system get sharemanagers.longhorn.io $VOL -o jsonpath='{.status.state}{"\n"}'
kubectl -n longhorn-system get volumeattachments.longhorn.io $VOL -o jsonpath='{.spec.attachmentTickets}' | jq 'keys'
kubectl -n longhorn-system get volumes.longhorn.io $VOL -o jsonpath='{.status.state}{"\n"}'
kubectl -n longhorn-system get pod share-manager-$VOL
kubectl get volumeattachments.storage.k8s.io -o json | jq -r --arg pv "$(kubectl get pv -o json | jq -r --arg v $VOL '.items[] | select(.spec.csi.volumeHandle==$v) | .metadata.name')" '.items[] | select(.spec.source.persistentVolumeName==$pv) | .metadata.name'
```

Continue only when the output is `stopped`, `[]`, `detached`, `NotFound`, and nothing, in that order. A CSI VolumeAttachment that was mid-attach finishes its current 90-second attach call before it processes the detach. Never remove its `external-attacher` finalizer by hand.

### Step 4: Attach the raw block device without the share-manager

```bash
export NODE=<engine-node>
kubectl -n longhorn-system patch volumeattachments.longhorn.io $VOL --type=merge -p "{\"spec\":{\"attachmentTickets\":{\"manual-xfs-repair\":{\"id\":\"manual-xfs-repair\",\"type\":\"longhorn-api\",\"nodeID\":\"$NODE\",\"parameters\":{\"disableFrontend\":\"false\"}}}}}"
kubectl -n longhorn-system get volumes.longhorn.io $VOL -o jsonpath='{.status.state} {.status.currentNodeID} {.status.robustness}{"\n"}'
kubectl -n longhorn-system get sharemanagers.longhorn.io $VOL -o jsonpath='{.status.state}{"\n"}'
```

Expect `attached <engine-node> healthy` and a share-manager that is still `stopped`. A large volume can take up to a minute to attach. If the share-manager leaves `stopped`, remove the ticket immediately (Step 8) and stop.

### Step 5: Open a privileged shell on the engine node

```bash
kubectl debug node/$NODE -n kube-system -it --profile=sysadmin --image=alpine:3.24.2 -- sh
```

Inside the debug shell:

```sh
apk add --no-cache xfsprogs xfsprogs-extra
xfs_repair -V
export DEV=/host/dev/longhorn/<longhorn-volume-name>
ls -l $DEV && blkid $DEV
```

`$DEV` must be a block device, and `blkid` must report `TYPE="xfs"` with the same UUID the kernel logged as corrupted. Device names such as `sdj` change on every attach, so compare the UUID, never the device name.

### Step 6: Read-only checks

```sh
mkdir -p /mnt/vol
mount -t xfs -o ro,norecovery $DEV /mnt/vol && ls /mnt/vol && df -h /mnt/vol
umount /mnt/vol
xfs_repair -n $DEV 2>&1 | tee /tmp/repair-n.log | tail -40
grep -cE 'bad|corrupt|disconnected|would junk|would clear' /tmp/repair-n.log
```

Neither command writes to the device. Decide from the output:

| Result | Decision |
|--------|----------|
| The `norecovery` mount lists the expected directories, and `xfs_repair -n` reports only a stale log (`Maximum metadata LSN ... is ahead of log`, `Would format log`) plus a handful of free-space entries | Go to Step 7 |
| Many inode or directory errors, `would junk`, or entries moved to `lost+found` | Stop. `-L` would lose files; reassess before writing anything |

`df` under `norecovery` reads counters that were never replayed from the journal, so its usage figure can be off. The figure after the repair is the accurate one.

### Step 7: Repair

```sh
xfs_repair $DEV
```

This is expected to refuse with `The filesystem has valuable metadata changes in a log which needs to be replayed`. That refusal confirms nothing changed since Step 6. The journal cannot be replayed, so clear it and repair:

```sh
xfs_repair -L $DEV 2>&1 | tee /tmp/repair-L.log | tail -30
mount -t xfs $DEV /mnt/vol && ls /mnt/vol && ls -A /mnt/vol/lost+found | wc -l && df -h /mnt/vol && umount /mnt/vol
exit
```

`xfs_repair -L` cannot be undone. It discards whatever metadata was still in the journal, at most the last few seconds before the failure. The plain mount (journal replay enabled) must succeed, and `lost+found` should be empty or close to it.

### Step 8: Remove the manual attachment and restart consumers

```bash
kubectl -n kube-system get pods -o name | grep node-debugger-$NODE | xargs kubectl -n kube-system delete
kubectl -n longhorn-system patch volumeattachments.longhorn.io $VOL --type=json -p '[{"op":"remove","path":"/spec/attachmentTickets/manual-xfs-repair"}]'
for a in $APPS; do flux -n flux-system resume helmrelease $a; done
for a in $APPS; do kubectl -n $NS scale deploy $a --replicas=1; done
```

A HelmRelease that had already failed before the outage needs `flux -n flux-system reconcile helmrelease <app> --force`.

## Verification

```bash
kubectl -n longhorn-system get sharemanagers.longhorn.io $VOL -o jsonpath='{.status.state}{"\n"}'
kubectl -n $NS get pods | grep -E "^(${(j:|:)APPS})-"
flux -n flux-system get helmreleases | grep -E "${(j:|:)APPS}"
kubectl get canaries -A
```

Expect the share-manager `running`, every consumer pod Running, every HelmRelease Ready, and the consumers' canaries passing. Then check every other Longhorn volume whose engine runs on the same node (see Warnings):

```bash
kubectl -n longhorn-system get volumes.longhorn.io -o json | jq -r --arg n $NODE '.items[] | select(.status.currentNodeID==$n) | "\(.metadata.name) \(.status.state) \(.status.robustness)"'
```

## Warnings

- No Longhorn snapshot is taken first. That is a deliberate choice for this cluster, where snapshots have repeatedly caused problems. Steps 6 and 7 are ordered so nothing writes to the device until the read-only checks pass.
- During the 2026-10-03 repair, the engine node's instance-manager died about a minute after the debug pod was deleted and the manual ticket removed (around 20:05 UTC). Every engine and replica on that node stopped at once and Garage's LMDB metadata database was corrupted. The cause was not determined. Run this repair when that node's other workloads can tolerate an instance-manager restart, and run the per-node volume check under Verification afterwards. See [garage-metadata-recovery.md](garage-metadata-recovery.md) if Garage is affected.

## Root Cause Context

On 2026-10-03 a Talos upgrade drained and rebooted the node running the 10Ti `media-library` volume's engine and share-manager. The engine was killed twice, once by the reboot sequence's pod shutdown and again by the reboot itself, while the filesystem was mounted and being written. `xfs_repair` then reported the on-disk metadata ahead of the journal. Related changes:

- [#1859](https://github.com/ionfury/homelab/pull/1859): `LonghornVolumeAttachmentStuck`, which would have fired within 30 minutes instead of the 10 hours it took to notice
- [#1860](https://github.com/ionfury/homelab/pull/1860): keeps failed replicas through Talos upgrades so returning nodes get delta rebuilds instead of full ones
- [#1856](https://github.com/ionfury/homelab/pull/1856): tuppr `drainTimeout`, for the separate node44 drain failure in the same upgrade

## Related

- [garage-metadata-recovery.md](garage-metadata-recovery.md)
- [resize-volume.md](resize-volume.md)
- `docs/investigations/longhorn-nsmounter-bug.md`
