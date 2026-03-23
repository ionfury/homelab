---
name: skill-inventory
description: Full skill inventory with type, purpose, composed-by, references, and scripts for all skills
type: reference
---

# Skill Inventory

## Background Skills (Agent-Composed)

These skills are composed by agents internally — not invoked directly by users.

| Skill | Purpose | Composed By | References | Scripts |
|-------|---------|-------------|------------|---------|
| `app-template` | Deploy applications using bjw-s/app-template Helm chart | implementer | patterns.md, values-reference.md | - |
| `architecture-review` | Architecture evaluation criteria and technology standards | designer | technology-decisions.md | - |
| `cnpg-database` | CNPG PostgreSQL cluster provisioning and credential management | implementer | - | - |
| `deploy-app` | End-to-end application deployment with monitoring integration | implementer | file-templates.md, monitoring-patterns.md | check-alerts.sh, check-canary.sh, check-deployment-health.sh, check-servicemonitor.sh |
| `flux-gitops` | Flux ResourceSet patterns for HelmRelease management | implementer | - | - |
| `gateway-routing` | Gateway API routing, TLS certificates, and WAF configuration | implementer | - | - |
| `gha-pipelines` | GitHub Actions CI/CD workflows, validation pipelines, OCI promotion | implementer | - | - |
| `grafana-dashboards` | MCP-driven Grafana dashboard authoring with visual iteration | implementer | - | - |
| `instruction-eval` | Behavioral regression testing for skill/CLAUDE.md changes | orchestrator | test-cases.md | run-eval.py |
| `k8s` | Kubernetes cluster access, kubectl, and Flux operations | troubleshooter, implementer, designer | - | - |
| `kubesearch` | Research Helm configurations from kubesearch.dev | designer, implementer | - | - |
| `loki` | Query Loki API for cluster logs and debugging | troubleshooter | - | logql.sh |
| `monitoring-authoring` | Author PrometheusRules, ServiceMonitors, AlertmanagerConfig, canary checks | implementer | - | - |
| `network-policy` | Cilium network policy management, Hubble debugging, escape hatch | troubleshooter, implementer | - | - |
| `opentofu-modules` | OpenTofu module development and testing patterns | implementer | opentofu-testing.md | - |
| `prometheus` | Query Prometheus API for metrics and alerts | troubleshooter | - | promql.sh |
| `promotion-pipeline` | OCI artifact promotion pipeline tracing and rollback | troubleshooter, implementer | - | - |
| `secrets` | Secret provisioning: secret-generator, ExternalSecret, app-secrets | implementer | - | - |
| `security-testing` | Adversarial security testing methodology and attack surface inventory | security-tester | attack-surface.md | - |
| `self-improvement` | Capture user feedback to enhance documentation | orchestrator | - | - |
| `sre` | Kubernetes incident investigation and debugging | troubleshooter | - | cluster-health.sh |
| `sync-claude` | Validate Claude docs against codebase state | orchestrator | - | discover-claude-docs.sh, extract-references.sh |
| `taskfiles` | Task runner syntax, patterns, and conventions | implementer | schema.md, cli.md, styleguide.md, task-catalog.md | - |
| `terragrunt` | Infrastructure operations with Terragrunt/OpenTofu | implementer | stacks.md, units.md | - |
| `versions-renovate` | Version management and Renovate annotation configuration | implementer | - | - |
