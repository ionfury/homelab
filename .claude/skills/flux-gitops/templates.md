# ResourceSet Template Reference

The `resourcesTemplate` in `helm-charts.yaml` uses Go text/template with `<<` `>>` delimiters.

## HelmRelease Template Pattern

```yaml
resourcesTemplate: |
  apiVersion: helm.toolkit.fluxcd.io/v2
  kind: HelmRelease
  metadata:
    name: << inputs.name >>
    namespace: << inputs.provider.namespace >>
  spec:
    <<- if inputs.dependsOn >>
    dependsOn:
    <<- range $dep := inputs.dependsOn >>
      - name: << $dep >>
    <<- end >>
    <<- end >>
    chart:
      spec:
        chart: << inputs.chart.name >>
        version: << inputs.chart.version >>
        sourceRef:
          <<- if hasPrefix "oci://" inputs.chart.url >>
          kind: HelmRepository
          <<- else >>
          kind: HelmRepository
          <<- end >>
          name: << inputs.name >>
          namespace: flux-system
    valuesFrom:
      - kind: ConfigMap
        name: platform-values
        valuesKey: << inputs.name >>.yaml
```

## HelmRepository Template Pattern

```yaml
  ---
  apiVersion: source.toolkit.fluxcd.io/v1
  kind: HelmRepository
  metadata:
    name: << inputs.name >>
    namespace: flux-system
  spec:
    <<- if hasPrefix "oci://" inputs.chart.url >>
    type: oci
    <<- end >>
    url: << inputs.chart.url >>
    interval: 12h
```
