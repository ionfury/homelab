# Longhorn nsmounter PID Resolution Bug on Talos Linux

**Date**: 2026-02-18
**Cluster**: live (Talos v1.12.4, Kubernetes v1.35.1, Longhorn v1.11.0)
**Status**: Investigation complete, pending validation
**Impact**: RWX (NFS-backed) volume mounts fail on affected nodes

---

## Symptom

The `media-library` PVC (10Ti, RWX, `slow-local` StorageClass) fails to mount on node42 with:

```
MountVolume.MountDevice failed for volume "pvc-2ef5cd2b-...":
rpc error: code = Internal desc = mount failed: exit status 1
Mounting command: /usr/local/sbin/nsmounter
Mounting arguments: mount -t nfs -o vers=4.1,noresvport,timeo=600,retrans=5,softerr
  172.19.1.73:/pvc-2ef5cd2b-... <mount-target>
Output: nsenter: cannot open /host/proc/scsi/ns/mnt: No such file or directory
```

Note: `/host/proc/scsi/` is a procfs pseudo-directory — not a PID. The `ns/mnt` namespace
path only exists under `/host/proc/<PID>/ns/mnt`.

Meanwhile, an identical RWX volume (`immich-library`, 500Gi, `slow` StorageClass) mounts
successfully on node2 using the same Longhorn version and NFS mechanism.

---

## Root Cause Analysis

### The nsmounter Script

Longhorn's CSI plugin uses `/usr/local/sbin/nsmounter` (a bash script) to perform NFS mounts
inside the host's mount namespace via `nsenter`. On Talos Linux, it searches `/host/proc/*/`
for the kubelet process to get the correct namespace path.

**Full script** (captured from the live CSI plugin container):

```bash
#!/bin/bash

PROC_DIR="/host/proc"
os_distro_talos="talos"
os_distro=""

get_os_distro() {
  local version_info=$(< $PROC_DIR/version)
  [[ $version_info =~ $os_distro_talos ]] && os_distro=$os_distro_talos
}

target_pid=1

get_pid() {
  local process_name=$1
  local pid
  local status_file
  local name                    # <-- declared local but never reset between iterations

  for dir in $PROC_DIR/*/; do
    pid=$(basename "$dir")
    status_file="$PROC_DIR/$pid/status"

    if [ -f "$status_file" ]; then
      while IFS= read -r line; do
        if [[ $line == "Name:"* ]]; then
          name="${line#*:}"
          name="${name//[$'\t ']/}"
          break
        fi
      done < "$status_file"
    fi
    # BUG: $name is NOT reset when $status_file doesn't exist.
    # Procfs pseudo-directories (acpi, bus, scsi, etc.) have no status file,
    # so $name retains its value from the previous iteration.
    if [ "$name" = "$process_name" ]; then
      target_pid=$pid           # <-- gets overwritten with pseudo-directory names!
    fi
  done
}

get_os_distro
[[ $os_distro = $os_distro_talos ]] && get_pid "kubelet"

ns_dir="$PROC_DIR/$target_pid/ns"
ns_mnt="$ns_dir/mnt"
ns_net="$ns_dir/net"
ns_uts="$ns_dir/uts"

nsenter --mount="$ns_mnt" --net="$ns_net" --uts="$ns_uts" -- "$@"
```

### The Bug

The `get_pid` function iterates ALL entries in `/host/proc/*/`, including procfs
pseudo-directories (`acpi/`, `bus/`, `driver/`, `fs/`, `irq/`, `net/`, `pressure/`,
`scsi/`, `self/`, `sys/`, `sysvipc/`, `thread-self/`, `tty/`).

The `$name` variable is **never reset between loop iterations**. When a pseudo-directory
(which lacks a `status` file) follows a PID whose name matched "kubelet", the stale
`$name` value causes `target_pid` to be overwritten with the pseudo-directory's basename.

**Bash glob expansion** sorts entries lexicographically. All numeric PIDs sort before
alphabetical pseudo-directories (digits 0x30-0x39 < lowercase 0x61-0x7A in ASCII):

```
/host/proc/1/ → /host/proc/10/ → ... → /host/proc/9955/ → /host/proc/99/ →
  /host/proc/acpi/ → /host/proc/bus/ → ... → /host/proc/scsi/ →
  /host/proc/self/ → /host/proc/sys/ → ... → /host/proc/tty/
```

After `self/` (which HAS a `status` file — it's a symlink to the current process),
`$name` gets updated to "bash" (since nsmounter is a bash script). This stops the
false matching. But `scsi/` comes BEFORE `self/` alphabetically, so `target_pid`
is already set to "scsi" by that point.

### Why node42 Fails But node2 Works

The bug triggers **only when the kubelet process PID is the lexicographically last
numeric entry** in `/host/proc/`. This depends on PID assignment at boot time.

**Evidence from live cluster** (captured 2026-02-18T17:48):

| Node | Last 3 PIDs (sorted) | Bug? |
|------|---------------------|------|
| **node42** | `9910 iscsid`, `9932 containerd-shim`, **`9955 kubelet`** | **YES** — kubelet is last numeric PID |
| node43 | `9967 xfsaild/sdb1`, `9975 containerd-shim`, `9999 iscsid` | No — iscsid is last |
| node41 | `9955 xfsaild/sdb1`, `9964 containerd-shim`, `9988 iscsid` | No — iscsid is last |
| node2 | `98764 kworker/12:0`, `98831 kworker/16:1`, `99 ksoftirqd/16` | No — ksoftirqd is last |

**On node42**: After PID 9955 (kubelet), the loop enters pseudo-directories with
`$name` still set to "kubelet". It overwrites `target_pid` through `acpi`, `bus`, ...,
`scsi`. Then `self/` (a valid entry with name="bash") breaks the pattern — but too late.
Final `target_pid = "scsi"`.

**On other nodes**: Other processes (iscsid, kworker, ksoftirqd) have higher PIDs than
kubelet, so `$name` changes before reaching the pseudo-directories. The false match
never occurs.

### Verification Steps

To validate this finding on any affected node:

```bash
# 1. Confirm the nsmounter script content matches the analysis above
KUBECONFIG=~/.kube/live.yaml kubectl exec -n longhorn-system \
  longhorn-csi-plugin-dmb66 -c longhorn-csi-plugin -- cat /usr/local/sbin/nsmounter

# 2. Confirm kubelet is the last numeric PID on node42
KUBECONFIG=~/.kube/live.yaml kubectl exec -n longhorn-system \
  longhorn-csi-plugin-dmb66 -c longhorn-csi-plugin -- bash -c '
  for d in /host/proc/*/; do
    pid=$(basename "$d")
    sf="/host/proc/$pid/status"
    if [ -f "$sf" ]; then
      while IFS= read -r line; do
        if [[ $line == "Name:"* ]]; then
          n="${line#*:}"; n="${n//[$'"'"'\t '"'"']/}"
          echo "$pid $n"; break
        fi
      done < "$sf"
    fi
  done | sort | tail -5'

# 3. Simulate the bug by running get_pid logic and printing target_pid
KUBECONFIG=~/.kube/live.yaml kubectl exec -n longhorn-system \
  longhorn-csi-plugin-dmb66 -c longhorn-csi-plugin -- bash -c '
  PROC_DIR="/host/proc"
  target_pid=1
  for dir in $PROC_DIR/*/; do
    pid=$(basename "$dir")
    status_file="$PROC_DIR/$pid/status"
    if [ -f "$status_file" ]; then
      while IFS= read -r line; do
        if [[ $line == "Name:"* ]]; then
          name="${line#*:}"; name="${name//[$'"'"'\t '"'"']/}"; break
        fi
      done < "$status_file"
    fi
    if [ "$name" = "kubelet" ]; then
      target_pid=$pid
    fi
  done
  echo "Final target_pid=$target_pid"
  echo "Expected: numeric PID of kubelet"
  echo "Actual path that nsenter will try: $PROC_DIR/$target_pid/ns/mnt"
  ls "$PROC_DIR/$target_pid/ns/mnt" 2>&1 || echo "(PATH DOES NOT EXIST - BUG CONFIRMED)"'
```

---

## Fix Options

### The Script Fix (Upstream)

Any of these changes to `nsmounter` would fix the bug:

**Option A**: Reset `$name` at the start of each iteration:
```bash
for dir in $PROC_DIR/*/; do
    pid=$(basename "$dir")
    name=""  # <-- ADD THIS LINE
    status_file="$PROC_DIR/$pid/status"
    ...
```

**Option B**: Break after finding kubelet (most efficient):
```bash
    if [ "$name" = "$process_name" ]; then
      target_pid=$pid
      break  # <-- ADD THIS (assumes we want the FIRST match)
    fi
```

**Option C**: Move the match inside the status file check:
```bash
    if [ -f "$status_file" ]; then
      ...
      if [ "$name" = "$process_name" ]; then
        target_pid=$pid
      fi
    fi
```

### Workaround Options

1. **Move pods off node42**: Cordon node42 so RWX-consuming pods schedule elsewhere.
   The NFS server (share-manager) can stay on node42; only the NFS client mount is broken.

2. **Reboot node42**: Changes PID assignment order. Not guaranteed to fix permanently
   (kubelet could get the last PID again).

3. **Patch nsmounter via Longhorn chart**: If Longhorn supports overriding the nsmounter
   script (e.g., via a ConfigMap mount), apply the fix locally. Needs chart investigation.

---

## Affected Components

| Component | Volume | Access Mode | Impact |
|-----------|--------|-------------|--------|
| sonarr | media-library | RWX | Pod stuck in ContainerCreating |
| jellyfin | media-library | RWX (read-only mount) | Will fail when scheduled on node42 |
| radarr | media-library | RWX (read-only mount) | Will fail when scheduled on node42 |
| Any future pod | Any RWX PVC | RWX | Fails on node42 until fix applied |

RWO volumes are unaffected (they don't use NFS/nsmounter).

---

## References

- Longhorn RWX docs: https://longhorn.io/docs/1.11.0/nodes-and-volumes/volumes/rwx-volumes/
- Talos storage guide: https://docs.siderolabs.com/kubernetes-guides/csi/storage
- Previous cross-kind dep fix in repo: commit `dd052978`
- Longhorn GitHub (no existing issue for this specific bug found)
