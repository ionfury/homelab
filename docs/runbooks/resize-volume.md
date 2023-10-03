# Resizing Volumes

Longhorn [supports volume expansion](https://longhorn.io/docs/archives/1.2.4/volumes-and-nodes/expansion/#expand-a-longhorn-volume), but something doesn't work quite right with the harvester integration.  The volume is resized from the kubernetes perspective and will show the correct size:

```sh
❯ kubectl get pvc -n media jellyfin-app-media
NAME                 STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
jellyfin-app-media   Bound    pvc-8fae9d64-e44f-4822-a0fd-efbd584bc1b0   10Ti       RWO            slow           57d
```

But the container will mount the volume with the wrong size (**98G** old size vs **10Ti** expected):

```sh
kah@jellyfin-app-6597d8bd9d-k2bjr:/media$ df -Th
Filesystem     Type     Size  Used Avail Use% Mounted on
...
/dev/sdi       ext4      98G   61G   38G  62% /media
...
```

`resize2fs` needs to be run from the k8s node on the filesystem.

## Manual Process

1. Identify the name of the PVC with the issue (in this case `pvc-8fae9d64-e44f-4822-a0fd-efbd584bc1b0`)

1. Find the node the mounting pod is running on:

```sh
❯ kubectl get po -o wide -n media jellyfin-app-6597d8bd9d-k2bjr
NAME                            READY   STATUS    RESTARTS       AGE   IP             NODE                              NOMINATED NODE   READINESS GATES
jellyfin-app-6597d8bd9d-k2bjr   1/1     Running   1 (149m ago)   15h   10.42.11.105   homelab-1-worker-fb46859b-d5cpw   <none>           <none>
```

1. Open the node in rancher: [https://rancher.tomnowak.work/dashboard/c/c-m-rtlw59pk/explorer/node/homelab-1-worker-fb46859b-d5cpw#pods](https://rancher.tomnowak.work/dashboard/c/c-m-rtlw59pk/explorer/node/homelab-1-worker-fb46859b-d5cpw#pods)

1. Click the `...` in the top-right and select `> SSH Shell`

1. Using the PVC name from #1 `lsblk | grep <pvc-name>` find the name of the mounted volume:

```sh
ubuntu@homelab-1-worker-fb46859b-d5cpw:~$ lsblk | grep pvc-8fae9d64-e44f-4822-a0fd-efbd584bc1b0
sdi       8:128  0   10T  0 disk /var/lib/kubelet/pods/394a6f17-2aad-4bb1-9287-fb4cef7513be/volumes/kubernetes.io~csi/pvc-8fae9d64-e44f-4822-a0fd-efbd584bc1b0/mount
```

1. Run the following to resize the volume:

```sh
ubuntu@homelab-1-worker-fb46859b-d5cpw:~$ sudo resize2fs /dev/sdi
resize2fs 1.45.5 (07-Jan-2020)
Filesystem at /dev/sdi is mounted on /var/lib/kubelet/pods/1518d001-8fbf-4d4a-912d-42da90f2d830/volumes/kubernetes.io~csi/pvc-8fae9d64-e44f-4822-a0fd-efbd584bc1b0/mount; on-line resizing required
old_desc_blocks = 13, new_desc_blocks = 1280
The filesystem on /dev/sdi is now 2684354560 (4k) blocks long.
```

> Note: It's **not** nessecary to unmount the volume first and can be done on an active filesystem.  To go from 100G to 10T took about 5 minutes.
