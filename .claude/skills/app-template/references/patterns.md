# app-template Common Patterns

Real-world deployment patterns from the bjw-s examples repository.

## Table of Contents

1. [Vaultwarden - Simple Stateful App](#vaultwarden)
2. [Home Assistant - StatefulSet with Code-Server Sidecar](#home-assistant)
3. [qBittorrent - VPN Sidecar with Port Forwarding](#qbittorrent)
4. [Init Containers](#init-containers)
5. [Multi-Path Ingress](#multi-path-ingress)

---

## Vaultwarden

Simple password manager with persistent storage and WebSocket support.

```yaml
# yaml-language-server: $schema=https://raw.githubusercontent.com/bjw-s-labs/helm-charts/app-template-4.6.0/charts/other/app-template/values.schema.json
controllers:
  main:
    strategy: Recreate

    containers:
      main:
        image:
          repository: vaultwarden/server
          tag: 1.25.2
          pullPolicy: IfNotPresent
        env:
          DATA_FOLDER: "config"

service:
  main:
    controller: main
    ports:
      http:
        port: 80
      websocket:
        enabled: true
        port: 3012

ingress:
  main:
    hosts:
      - host: vaultwarden.example.com
        paths:
          - path: /
            pathType: Prefix
            service:
              identifier: main
              port: http
          - path: /notifications/hub/negotiate
            pathType: Prefix
            service:
              identifier: main
              port: http
          - path: /notifications/hub
            pathType: Prefix
            service:
              identifier: main
              port: websocket

persistence:
  config:
    type: persistentVolumeClaim
    accessMode: ReadWriteOnce
    size: 1Gi
    globalMounts:
      - path: /config
```

**Key patterns:**
- `strategy: Recreate` for stateful apps (prevents dual-write issues)
- Multiple service ports for HTTP + WebSocket
- Path-based routing to different ports in single ingress

---

## Home Assistant

StatefulSet with code-server sidecar for config editing.

```yaml
# yaml-language-server: $schema=https://raw.githubusercontent.com/bjw-s-labs/helm-charts/app-template-4.6.0/charts/other/app-template/values.schema.json
defaultPodOptions:
  automountServiceAccountToken: false
  securityContext:
    runAsUser: 568
    runAsGroup: 568
    fsGroup: 568
    fsGroupChangePolicy: "OnRootMismatch"

controllers:
  main:
    type: statefulset
    annotations:
      reloader.stakater.com/auto: "true"

    containers:
      main:
        image:
          repository: ghcr.io/onedr0p/home-assistant
          tag: 2023.11.2

      code:
        dependsOn: main
        image:
          repository: ghcr.io/coder/code-server
          tag: 4.19.0
        args:
          - --auth
          - "none"
          - --user-data-dir
          - "/config/.vscode"
          - --extensions-dir
          - "/config/.vscode"
          - --port
          - "8081"
          - "/config"

service:
  main:
    controller: main
    type: ClusterIP
    ports:
      http:
        port: 8123
  code:
    type: ClusterIP
    controller: main
    ports:
      http:
        port: 8081

ingress:
  main:
    className: "external-nginx"
    hosts:
      - host: &host "hass.example.local"
        paths:
          - path: /
            pathType: Prefix
            service:
              identifier: main
              port: http
    tls:
      - hosts:
          - *host
  code:
    className: "internal-nginx"
    hosts:
      - host: &host-code "hass-code.example.local"
        paths:
          - path: /
            pathType: Prefix
            service:
              identifier: code
              port: http
    tls:
      - hosts:
          - *host-code

persistence:
  config:
    existingClaim: home-assistant-config
    globalMounts:
      - path: /config

  backup:
    type: nfs
    server: nas.example.lan
    path: /volume/Backups/k8s/hass
    globalMounts:
      - path: /config/backups
```

**Key patterns:**
- `type: statefulset` for stable pod identity
- `dependsOn: main` ensures sidecar starts after main container
- Separate services and ingresses for main app and code-server
- YAML anchors (`&host`, `*host`) for DRY configuration
- `reloader.stakater.com/auto: "true"` for automatic config reload
- NFS mount for external backup storage

---

## qBittorrent

Application with gluetun VPN sidecar and port forwarding.

```yaml
# yaml-language-server: $schema=https://raw.githubusercontent.com/bjw-s-labs/helm-charts/app-template-4.6.0/charts/other/app-template/values.schema.json
defaultPodOptions:
  automountServiceAccountToken: false

controllers:
  main:
    annotations:
      reloader.stakater.com/auto: "true"

    pod:
      securityContext:
        fsGroup: 568
        fsGroupChangePolicy: "OnRootMismatch"

    containers:
      main:
        image:
          repository: ghcr.io/onedr0p/qbittorrent
          tag: 4.6.0
        securityContext:
          runAsUser: 568
          runAsGroup: 568

      gluetun:
        dependsOn: main
        image:
          repository: ghcr.io/qdm12/gluetun
          tag: latest
        env:
          VPN_TYPE: wireguard
          VPN_INTERFACE: wg0
        securityContext:
          capabilities:
            add:
              - NET_ADMIN

      port-forward:
        dependsOn: gluetun
        image:
          repository: docker.io/snoringdragon/gluetun-qbittorrent-port-manager
          tag: "1.0"
        env:
          - name: QBITTORRENT_SERVER
            value: localhost
          - name: QBITTORRENT_PORT
            value: "8080"
          - name: PORT_FORWARDED
            value: "/tmp/gluetun/forwarded_port"

service:
  main:
    controller: main
    type: ClusterIP
    ports:
      http:
        port: 8080

ingress:
  main:
    className: "external-nginx"
    hosts:
      - host: &host "qb.example.local"
        paths:
          - path: /
            pathType: Prefix
            service:
              identifier: main
              port: http
    tls:
      - hosts:
          - *host

persistence:
  config:
    existingClaim: qbittorrent-config
    advancedMounts:
      main:
        main:
          - path: /config

  gluetun-data:
    type: emptyDir
    advancedMounts:
      main:
        gluetun:
          - path: /tmp/gluetun
        port-forward:
          - path: /tmp/gluetun
            readOnly: true
```

**Key patterns:**
- Container ordering: `main` → `gluetun` → `port-forward`
- VPN sidecar with `NET_ADMIN` capability
- `advancedMounts` for container-specific volume paths
- `emptyDir` for inter-container communication via shared files
- Different security contexts per container

---

## Init Containers

Run setup tasks before main containers start.

```yaml
controllers:
  main:
    initContainers:
      init-config:
        image:
          repository: busybox
          tag: latest
        command:
          - /bin/sh
          - -c
          - |
            if [ ! -f /config/config.yaml ]; then
              cp /defaults/config.yaml /config/config.yaml
            fi

      wait-for-db:
        image:
          repository: busybox
          tag: latest
        command:
          - /bin/sh
          - -c
          - |
            until nc -z postgres-service 5432; do
              echo "Waiting for database..."
              sleep 2
            done

    containers:
      main:
        image:
          repository: myapp
          tag: v1.0.0

persistence:
  config:
    type: persistentVolumeClaim
    size: 1Gi
    globalMounts:
      - path: /config

  defaults:
    type: configMap
    name: app-defaults
    globalMounts:
      - path: /defaults
```

**Key patterns:**
- Init containers run in order before main containers
- Use for config initialization, migrations, dependency checks
- Same volume mounts apply to init containers via `globalMounts`

---

## Multi-Path Ingress

Route different paths to different services/ports.

```yaml
service:
  frontend:
    controller: main
    ports:
      http:
        port: 3000

  api:
    controller: main
    ports:
      http:
        port: 8080

  websocket:
    controller: main
    ports:
      ws:
        port: 9000

ingress:
  main:
    className: nginx
    annotations:
      nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
      nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
    hosts:
      - host: app.example.com
        paths:
          - path: /
            pathType: Prefix
            service:
              identifier: frontend
              port: http
          - path: /api
            pathType: Prefix
            service:
              identifier: api
              port: http
          - path: /ws
            pathType: Prefix
            service:
              identifier: websocket
              port: ws
    tls:
      - hosts:
          - app.example.com
        secretName: app-tls
```

**Key patterns:**
- Multiple services targeting the same controller
- Path-based routing in ingress
- Ingress annotations for WebSocket timeout configuration
