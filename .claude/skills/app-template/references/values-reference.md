# app-template Values Reference

Complete reference for all configuration options in the bjw-s/app-template chart.

## Table of Contents

1. [Global](#global)
2. [Default Pod Options](#default-pod-options)
3. [Controllers](#controllers)
4. [Containers](#containers)
5. [Services](#services)
6. [Ingress](#ingress)
7. [Persistence](#persistence)
8. [ServiceMonitor](#servicemonitor)
9. [Gateway Routes](#gateway-routes)
10. [Network Policies](#network-policies)
11. [Secrets & ConfigMaps](#secrets--configmaps)
12. [RBAC](#rbac)

---

## Global

```yaml
global:
  nameOverride:           # Override fullname prefix
  fullnameOverride:       # Set entire name definition
  propagateGlobalMetadataToPods: false
  labels: {}              # Additional global labels (Helm templates supported)
  annotations: {}         # Additional global annotations
```

---

## Default Pod Options

Applied to all pods unless overridden at controller level.

```yaml
defaultPodOptionsStrategy: overwrite  # overwrite|merge

defaultPodOptions:
  # Scheduling
  affinity: {}
  nodeSelector: {}
  tolerations: []
  topologySpreadConstraints: []
  priorityClassName: ""
  schedulerName: ""

  # Security
  securityContext: {}              # Pod-level security context
  automountServiceAccountToken: true

  # Network
  dnsConfig: {}
  dnsPolicy: ""                    # ClusterFirst|ClusterFirstWithHostNet
  enableServiceLinks: false
  hostname: ""
  hostAliases: []
  hostIPC: false
  hostNetwork: false
  hostPID: false
  hostUsers:                       # Requires K8s 1.29+

  # Other
  imagePullSecrets: []
  labels: {}
  annotations: {}
  restartPolicy: ""                # Always|Never (Never for cronjob)
  runtimeClassName: ""
  shareProcessNamespace:
  terminationGracePeriodSeconds:
```

---

## Controllers

```yaml
controllers:
  <identifier>:
    enabled: true
    type: deployment               # deployment|statefulset|daemonset|cronjob|job
    annotations: {}
    labels: {}
    replicas: 1                    # Set to null for HPA
    revisionHistoryLimit: 3

    # Deployment/StatefulSet strategy
    strategy:                      # Recreate|RollingUpdate (deployment)
                                   # OnDelete|RollingUpdate (statefulset)
    rollingUpdate:
      unavailable:                 # Deployment max unavailable
      surge:                       # Deployment max surge
      partition:                   # StatefulSet partition

    # Service account
    serviceAccount:
      identifier:                  # Reference serviceAccount from values
      name:                        # Explicit name

    # Pod disruption budget
    podDisruptionBudget:
      minAvailable: 1
      # OR
      maxUnavailable: 1

    # Controller-specific pod options (override defaults)
    pod: {}

    # CronJob configuration
    cronjob:
      suspend: false
      concurrencyPolicy: Forbid    # Allow|Forbid|Replace
      timeZone:                    # K8s 1.27+
      schedule: "*/20 * * * *"
      startingDeadlineSeconds: 30
      successfulJobsHistory: 1
      failedJobsHistory: 1
      ttlSecondsAfterFinished:
      backoffLimit: 6
      parallelism:

    # Job configuration
    job:
      suspend: false
      ttlSecondsAfterFinished:
      backoffLimit: 6
      parallelism:
      completions:
      completionMode:

    # StatefulSet configuration
    statefulset:
      podManagementPolicy:         # Parallel|OrderedReady
      volumeClaimTemplates:
        - name: data
          labels: {}
          annotations: {}
          accessMode: ReadWriteOnce
          size: 1Gi
          storageClass:
          dataSourceRef:           # For volume snapshots
            apiGroup: snapshot.storage.k8s.io
            kind: VolumeSnapshot
            name: MySnapshot
          globalMounts:
            - path: /data
              subPath:

    # Container options
    applyDefaultContainerOptionsToInitContainers: true
    defaultContainerOptionsStrategy: overwrite
    defaultContainerOptions: {}    # Same structure as container config

    containers: {}                 # See Containers section
    initContainers: {}             # Same structure as containers
```

---

## Containers

```yaml
controllers:
  main:
    containers:
      <identifier>:
        nameOverride:              # Override container name
        dependsOn: []              # Container ordering

        image:
          repository:
          tag:
          digest:                  # Use instead of tag for immutable refs
          pullPolicy:              # Always|IfNotPresent|Never

        command: []
        args: []
        workingDir:

        # Environment variables
        env:
          # Simple value
          TZ: UTC
          # Helm template
          RELEASE: "{{ .Release.Name }}"
          # With dependency
          AFTER_VAR:
            value: "value"
            dependsOn: OTHER_VAR
          # From ConfigMap
          CONFIG_VAL:
            configMapKeyRef:
              name: config-map-name
              key: key-name
          # From Secret
          SECRET_VAL:
            valueFrom:
              secretKeyRef:
                name: secret-name
                key: key-name
          # List format
          - name: TZ
            value: UTC

        # Load from ConfigMap/Secret
        envFrom:
          # By identifier (from this values.yaml)
          - config: config-identifier
          - secret: secret-identifier
          # By name
          - configMapRef:
              name: configmap-name
          - secretRef:
              name: secret-name

        # Probes
        probes:
          liveness:
            enabled: true
            custom: false          # Set true for custom spec
            type: TCP              # TCP|HTTP|HTTPS
            spec:
              initialDelaySeconds: 0
              periodSeconds: 10
              timeoutSeconds: 1
              failureThreshold: 3
              # For HTTP type
              httpGet:
                path: /health
                port: 8080
          readiness:
            enabled: true
            custom: false
            type: TCP
            spec:
              initialDelaySeconds: 0
              periodSeconds: 10
              timeoutSeconds: 1
              failureThreshold: 3
          startup:
            enabled: true
            custom: false
            type: TCP
            spec:
              initialDelaySeconds: 0
              timeoutSeconds: 1
              periodSeconds: 5
              failureThreshold: 30  # 5*30=150s max startup

        resources:
          limits:
            cpu: 100m
            memory: 128Mi
          requests:
            cpu: 100m
            memory: 128Mi

        securityContext:
          runAsUser: 568
          runAsGroup: 568
          capabilities:
            add: []
            drop: []

        lifecycle:
          postStart:
            exec:
              command: ["/bin/sh", "-c", "echo started"]
          preStop:
            exec:
              command: ["/bin/sh", "-c", "echo stopping"]

        terminationMessagePath:
        terminationMessagePolicy:  # File|FallbackToLogsOnError
```

---

## Services

```yaml
service:
  <identifier>:
    enabled: true
    controller: main               # Target controller
    primary: true                  # Primary service for probes/notes

    type: ClusterIP                # ClusterIP|LoadBalancer|NodePort

    internalTrafficPolicy:         # Cluster|Local
    externalTrafficPolicy:         # Cluster|Local

    ipFamilyPolicy:                # SingleStack|PreferDualStack|RequireDualStack
    ipFamilies: []                 # [IPv4, IPv6]

    annotations: {}
    labels: {}
    extraSelectorLabels: {}

    ports:
      <port-identifier>:
        enabled: true
        primary: true              # Primary port for probes
        port: 80
        protocol: HTTP             # HTTP|HTTPS|TCP|UDP
        targetPort:                # If different from port
        nodePort:                  # For NodePort/LoadBalancer
        appProtocol:               # K8s appProtocol field
```

---

## Ingress

```yaml
ingress:
  <identifier>:
    enabled: true
    nameOverride:
    annotations: {}                # Helm templates supported
    labels: {}
    className:                     # Ingress class name

    defaultBackend:                # Disables other rules if set

    hosts:
      - host: chart-example.local  # Helm template supported
        paths:
          - path: /                # Helm template supported
            pathType: Prefix       # Prefix|Exact|ImplementationSpecific
            service:
              name:                # Service name override
              identifier: main     # Reference service.main
              port:                # Port number or name

    tls:
      - secretName: tls-secret     # Helm template supported
        hosts:                     # Helm template supported
          - chart-example.local
```

---

## Persistence

```yaml
persistence:
  <identifier>:
    enabled: true
    type: persistentVolumeClaim    # persistentVolumeClaim|emptyDir|nfs|
                                   # hostPath|secret|configMap|custom

    # For persistentVolumeClaim
    storageClass:                  # "-" disables dynamic provisioning
    existingClaim:                 # Use existing PVC
    dataSource: {}                 # Volume populator
    dataSourceRef: {}              # Volume populator
    accessMode: ReadWriteOnce      # RWO|RWX|ROX
    size: 1Gi
    retain: false                  # Retain PVC on helm uninstall

    # For nfs
    server: nfs.example.com
    path: /exports/data

    # For hostPath
    hostPath: /host/path
    hostPathType:                  # DirectoryOrCreate|Directory|FileOrCreate|
                                   # File|Socket|CharDevice|BlockDevice

    # For secret/configMap
    name: secret-or-configmap-name
    defaultMode: 0644
    items:
      - key: config.yaml
        path: app/config.yaml

    # Mount configuration
    globalMounts:                  # Mount to all containers
      - path: /config
        readOnly: false
        subPath:
        mountPropagation:          # None|HostToContainer|Bidirectional

    advancedMounts:                # Mount to specific containers
      <controller>:
        <container>:
          - path: /config
            readOnly: false
            subPath:
            mountPropagation:
```

---

## ServiceMonitor

For Prometheus operator integration.

```yaml
serviceMonitor:
  <identifier>:
    enabled: false
    nameOverride: ""
    annotations: {}
    labels: {}

    selector: {}                   # Custom selector (overrides serviceName)
    serviceName: '{{ include "bjw-s.common.lib.chart.names.fullname" $ }}'

    endpoints:
      - port: http
        scheme: http
        path: /metrics
        interval: 1m
        scrapeTimeout: 10s

    targetLabels: []               # Service labels to copy to metrics
```

---

## Gateway Routes

For Kubernetes Gateway API.

```yaml
route:
  <identifier>:
    enabled: false
    kind: HTTPRoute                # GRPCRoute|HTTPRoute|TCPRoute|TLSRoute|UDPRoute
    nameOverride: ""
    annotations: {}
    labels: {}

    parentRefs:
      - group: gateway.networking.k8s.io
        kind: Gateway
        name: gateway-name
        namespace: gateway-namespace
        sectionName: section-name

    hostnames: []                  # Helm template supported

    rules:
      - name: ""                   # Optional unique name
        backendRefs: []
        matches:
          - path:
              type: PathPrefix
              value: /
        filters: []
        timeouts: {}
```

---

## Network Policies

```yaml
networkpolicies:
  <identifier>:
    enabled: false
    controller: main               # Target controller
    podSelector: {}                # Custom selector (overrides controller)

    policyTypes:
      - Ingress
      - Egress

    rules:
      ingress:
        - {}                       # Allow all by default
      egress:
        - {}                       # Allow all by default
```

---

## Secrets & ConfigMaps

```yaml
secrets:
  <identifier>:
    enabled: false
    labels: {}
    annotations: {}
    stringData:                    # Helm templates supported
      key: value

configMaps:
  <identifier>:
    enabled: true
    labels: {}
    annotations: {}
    data:                          # Helm templates supported
      key: value

# Generate ConfigMaps from folder
configMapsFromFolder:
  enabled: false
  basePath: "files/configMaps"
  configMapsOverrides:
    <folder-name>:
      forceRename:
      annotations: {}
      labels: {}
      fileAttributeOverrides:
        <filename>:
          exclude: false
          binary: false            # For image files
          escaped: true            # Don't template gotpl syntax
```

---

## RBAC

```yaml
rbac:
  roles:
    <identifier>:
      forceRename:
      enabled: true
      type: Role                   # Role|ClusterRole
      rules:
        - apiGroups: ["*"]
          resources: ["*"]
          verbs: ["get", "list", "watch"]

  bindings:
    <identifier>:
      forceRename:
      enabled: true
      type: RoleBinding            # RoleBinding|ClusterRoleBinding
      roleRef:
        name: role-name
        kind: Role
        identifier:                # Reference rbac.roles identifier
      subjects:
        - identifier: default      # Reference serviceAccount identifier
        - kind: ServiceAccount
          name: sa-name
          namespace: "{{ .Release.Namespace }}"
        - kind: Group
          name: oidc:/group
        - kind: User
          name: username

serviceAccount:
  <identifier>:
    enabled: false
    annotations: {}
    labels: {}
```

---

## Raw Resources

Create arbitrary Kubernetes resources.

```yaml
rawResources:
  <identifier>:
    enabled: false
    apiVersion: v1
    kind: Endpoint
    nameOverride: ""
    annotations: {}
    labels: {}
    spec: {}                       # Resource-specific spec
```
