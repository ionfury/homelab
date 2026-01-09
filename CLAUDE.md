# Homelab Infrastructure - Claude Reference

Enterprise-grade bare-metal Kubernetes infrastructure managed declaratively from PXE to production workloads.

---

# CORE PRINCIPLES

## Enterprise at Home

This is not a hobby project with shortcuts. Every decision should reflect production-grade thinking:
- **No shortcuts**: If it wouldn't pass a production review, don't do it here
- **Complexity is a feature**: The goal is to build skills with enterprise patterns, not to find the easiest path
- **Aim for perfection**: Over-engineering is intentional - this is a learning environment for mastering resilience, reliability, observability, and automation

## Everything as Code

The git repository IS the system state. If it's not in git, it doesn't exist:
- **Full state representation**: Every configuration, secret reference, network rule, and machine property lives in version control
- **No manual changes**: Never `kubectl apply` manually, never SSH to fix things, never click in a UI to configure
- **Drift is failure**: If actual state diverges from git state, that's a bug to fix, not a state to accept

## Automation is Key

Manual processes are technical debt. Automate aggressively:
- **Automate first**: Before doing something manually, ask "how do I automate this?"
- **Self-healing systems**: Systems should detect and recover from failures without intervention
- **Repeatable operations**: Any operation should be runnable N times with identical results

## Learning First

This infrastructure exists to develop enterprise skills:
- **Production patterns**: Use the same patterns you'd see in a Fortune 500 company
- **Observability depth**: Full metrics, logs, traces, and profiling - understand what's happening
- **Failure modes**: Design for failure, test failure, learn from failure

---

# ANTI-PATTERNS (NEVER DO THESE)

## Security

- **NEVER** commit secrets or credentials to Git - they belong in AWS Parameter Store
- **NEVER** commit generated artifacts (`.rendered/`, `.terragrunt-cache/`, etc.)

## Destructive Operations (Require EXPLICIT Human Authorization)

- **NEVER** run `terragrunt apply` or `tofu apply` without explicit human approval
- **NEVER** use `--auto-approve` flags in Terragrunt/OpenTofu commands
- **NEVER** delete resources without explicit human approval
- **NEVER** use git commands (commit, push, rebase, etc.) without explicit human approval

## Kubernetes Safety

- **NEVER** use `kubectl --force --grace-period=0` or `--ignore-not-found` flags
- **NEVER** modify CRD definitions without understanding operator compatibility
- **NEVER** apply changes directly to the cluster - always use the GitOps approach through Flux
- **NEVER** hallucinate YAML fields - use `kubectl explain`, official docs, or YAML schema validation

## Verification

- **NEVER** guess resource names, strings, IPs, or values - VERIFY against source files
- **NEVER** skip validation steps (`task tg:fmt`, `task tg:validate`, `task k8s:render`) before committing
- **NEVER** ignore deprecation warnings - implement migrations immediately

## Documentation

- **NEVER** leave documentation stale after completing tasks - update CLAUDE.md, README, or runbooks as needed
- **NEVER** create summary docs about work performed - the git history is the record

---

# PHILOSOPHY

This repository pushes the boundaries of "infrastructure as code" - starting from BIOS configuration and ending at SLO dashboards. Every component is:
- **Declarative**: No manual steps, no imperative scripts
- **Reproducible**: Any cluster can be rebuilt from scratch in minutes
- **GitOps-driven**: Git is the source of truth, Flux reconciles state
- **Hands-off**: Once deployed, the system self-heals and self-updates
- **Observable**: If you can't measure it, you can't improve it

## Repository Structure

```
infrastructure/           # Terragrunt/OpenTofu - provisions bare metal to Kubernetes
  ├── stacks/            # Cluster deployments (dev, integration)
  ├── units/             # Reusable Terragrunt units
  ├── modules/           # Terraform modules
  ├── inventory.hcl      # Hardware inventory
  ├── networking.hcl     # Network topology
  ├── versions.hcl       # Pinned versions
  └── accounts.hcl       # External service credentials

kubernetes/              # Flux GitOps - deploys workloads
  ├── clusters/          # Per-cluster configs
  │   ├── base/          # Shared across all clusters
  │   ├── live/          # Production
  │   ├── integration/   # Testing
  │   └── dev/           # Development (Pi)
  └── manifests/         # Reusable manifests
      ├── helm-release/  # Helm chart releases
      └── common/        # Shared templates
```

## Domain-Specific References

For detailed patterns and operations in specific areas, see:
- **`infrastructure/CLAUDE.md`** - Terragrunt/OpenTofu patterns, units vs stacks, HCL conventions

## Development Environment

All required CLI tools are defined in the `Brewfile`. Install them with:

```bash
brew bundle
```

This installs: `gh`, `awscli`, `kubectl`, `helm`, `kustomize`, `flux`, `go-task`, `tgenv`, `tofuenv`, `talosctl`, `cilium-cli`, and other dependencies.

**Opinion**: Always install tools via Brewfile. Never install CLI tools manually - if a tool is missing, add it to the Brewfile first.

---

# KUBERNETES OPINIONS (Flux GitOps)

## Helm Release Pattern

**ALL Helm releases MUST use the base template pattern.** Never create inline HelmRelease resources.

Structure:
```
kubernetes/manifests/helm-release/<name>/
├── kustomization.yaml    # Patches base template
├── values.yaml           # Helm values
└── (optional) canary.yaml, external-secret.yaml
```

The `kustomization.yaml` MUST:
1. Set `namePrefix: <name>-`
2. Reference `../../common/resources/helm-release` as base
3. Use `configMapGenerator` to inject values.yaml
4. Patch HelmRelease with chart name and release name
5. Patch HelmRepository with repository URL

```yaml
# CORRECT pattern - always follow this structure
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namePrefix: grafana-
resources:
  - ../../common/resources/helm-release
configMapGenerator:
  - name: values
    behavior: replace
    files:
      - values.yaml
patches:
  - target:
      kind: HelmRelease
    patch: |-
      - op: replace
        path: /spec/chart/spec/chart
        value: grafana
      - op: add
        path: /spec/releaseName
        value: grafana
  - target:
      kind: HelmRepository
      name: app
    patch: |-
      - op: replace
        path: /spec/url
        value: https://grafana.github.io/helm-charts
```

## Namespace Organization

Each namespace in `kubernetes/clusters/base/<namespace>/`:
1. MUST include the namespace resource: `../../../manifests/common/resources/namespace`
2. MUST set `namespace:` at the top of kustomization.yaml
3. Contains Flux Kustomization resources (not raw manifests)

```yaml
# CORRECT namespace kustomization
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: monitoring
resources:
  - ../../../manifests/common/resources/namespace
  - grafana.yaml           # Flux Kustomization, NOT HelmRelease
  - prometheus.yaml
```

## Flux Kustomization Resources

Workloads are deployed via Flux Kustomization resources that point to manifests:

```yaml
# CORRECT: Flux Kustomization pointing to helm-release
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: grafana
spec:
  path: kubernetes/manifests/helm-release/grafana
  dependsOn:
    - name: kube-prometheus-stack    # Explicit dependency
  postBuild:
    substitute:
      HELM_CHART_VERSION: 8.8.5      # Version set HERE, not in values.yaml
```

**Opinion**:
- Chart versions go in `postBuild.substitute`, NOT in values.yaml
- Dependencies between releases go in `dependsOn`, NOT in Helm dependencies
- Namespace is inherited from the parent kustomization, NOT set per-release

## Variable Substitution

Flux performs variable substitution at reconciliation time. Use these patterns:

```yaml
# Simple substitution
url: https://grafana.${internal_domain}

# With default value
namespace: ${NAMESPACE:=monitoring}

# Cluster-specific (set in generated-cluster-vars.env)
cluster: ${cluster_name}
```

**Available variables** (from cluster config):
- `${internal_domain}` - Internal TLD (e.g., internal.tomnowak.work)
- `${external_domain}` - External TLD
- `${cluster_name}` - Cluster name (dev, integration, live)
- `${cluster_id}` - Numeric cluster ID
- `${HELM_CHART_VERSION}` - Set per-release in Flux Kustomization

**Opinion**: Never hardcode domains, cluster names, or versions. Always use substitution.

## Network Policies

Network policies use the **Kustomize Components** pattern in `.network-policies/`:

```
.network-policies/
├── allow-same-namespace/source/
├── allow-ingress-from-internal/
│   ├── source/       # Applied to nginx
│   └── destination/  # Applied to target pods
├── allow-egress-to-private/source/
```

**To enable network policies for a namespace:**
1. Uncomment `components: - ../.network-policies` in namespace kustomization
2. Add labels to pods that need specific access:
   - `networking/allow-ingress-from-internal: "true"` - Accept internal ingress
   - `networking/allow-egress-to-private: "true"` - Allow RFC1918 egress
   - `networking/allow-ingress-prometheus: "true"` - Allow Prometheus scraping

**Opinion**: Default deny is opt-in via `allow-same-namespace`. When enabling, be explicit about what traffic is allowed using labels.

## Cluster Hierarchy

```
base/     → Shared by ALL clusters (core infrastructure)
  ↓
live/     → Production-specific overrides
staging/  → Staging-specific overrides
integration/ → Integration-specific overrides
dev/      → Development-specific overrides (ARM64 compatible)
```

**Opinion**: Put everything possible in `base/`. Only use cluster-specific directories for:
- Hardware-specific configs (ARM64 vs AMD64)
- Environment-specific secrets
- Scale/resource differences

---

# CODE STYLE

## YAML (Kubernetes)
- Include schema comment: `# yaml-language-server: $schema=...`
- Use `---` document separator at file start
- 2-space indentation
- Quote strings that could be misinterpreted (especially "true"/"false")

## Naming Conventions
| Resource | Convention | Example |
|----------|------------|---------|
| Helm release directory | kebab-case, matches chart | `kube-prometheus-stack/` |
| Flux Kustomization name | kebab-case, matches release | `name: kube-prometheus-stack` |
| Namespace | kebab-case | `longhorn-system` |
| ConfigMap/Secret | kebab-case with suffix | `grafana-values`, `app-secret` |

---

# UNIVERSAL STANDARDS

## Documentation Philosophy

Code should be self-documenting. Comments and messages explain the WHY, not the WHAT.

**Guiding principles:**
- **Self-documenting code**: Use clear names, logical structure, and obvious patterns
- **Comments explain reasoning**: Why this approach? Why not the obvious alternative?
- **Omit the obvious**: Don't comment what the code clearly does
- **No redundancy**: If the code says it, don't repeat it in a comment

```hcl
# BAD: Restates what the code does
# Set the cluster name to "live"
cluster_name = "live"

# GOOD: Explains why
# Production cluster - receives traffic after promotion through dev/integration
cluster_name = "live"

# BEST: Self-documenting, no comment needed
production_cluster_name = "live"
```

## Commits

Follow Conventional Commits format:

```
<type>(<scope>): <short description>

[optional body - explain WHY, not WHAT]

[optional footer]
```

**Commit message rules:**
- **Description**: One short line summarizing the contribution at a high level
- **Focus on WHY**: Explain the reasoning and intent, not the changes themselves
- **The diff shows WHAT**: Don't restate file changes - reviewers can see the diff
- **Be concise**: If you need paragraphs, the commit is probably too big

```bash
# BAD: Restates the changes
docs(docs): add CLAUDE.md with core principles section containing enterprise
at home philosophy and everything as code section and anti-patterns section
with 14 rules organized into 5 categories and kubernetes opinions...

# GOOD: Explains the why at a high level
docs(docs): add Claude Code context for repository conventions

# GOOD: With body explaining reasoning
feat(infra): add node50 to live cluster

Expanding capacity for increased workload from new monitoring stack.
```

**Types:** `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`, `ci`

**Scopes:** `k8s`, `infra`, `apps`, `docs`, `network`, `storage`, `platform`

**Breaking changes** require footer: `BREAKING CHANGE: <description>`

**No Claude signoff**: Do not include `Co-Authored-By: Claude` in commits. The existence of this CLAUDE.md file documents AI assistance in this repository.

## Pull Requests

PRs follow the same philosophy as commits: explain WHY, not WHAT. The diff speaks for itself.

**Structure:**
```markdown
## Summary
<1-3 bullet points explaining the purpose and motivation>

## Test plan
<Checklist of verification steps>
```

**PR description rules:**
- **Summary explains intent**: Why is this change being made? What problem does it solve?
- **Don't enumerate files**: Reviewers can see what changed in the diff
- **Don't describe obvious changes**: "Updated X" is noise - explain why X needed updating
- **Test plan is actionable**: Specific steps someone can follow to verify the change works

```markdown
# BAD: Restates the diff
## Summary
- Modified infrastructure/modules/talos/main.tf to add new variable
- Updated infrastructure/stacks/live/terragrunt.hcl to pass variable
- Changed kubernetes/clusters/base/monitoring/grafana.yaml version

# GOOD: Explains the reasoning
## Summary
- Enable persistent storage for Grafana dashboards to survive pod restarts
- Upgrade Grafana to v10.x for new alerting features needed by on-call rotation

## Test plan
- [ ] Verify Grafana pod starts with PVC mounted
- [ ] Confirm existing dashboards load after pod restart
- [ ] Test new alerting rule creation in UI
```

---

# TESTING & VALIDATION

Testing is non-negotiable. Every change must pass validation before being considered ready.

## Required Validation Steps

**ALWAYS run these before requesting commit approval:**

```bash
# 1. Format all code
task tg:fmt                        # Formats HCL (Terragrunt + OpenTofu)

# 2. Validate infrastructure
task tg:validate                   # Validates all Terragrunt stacks

# 3. Render and validate Kubernetes manifests
task k8s:render                    # Renders all clusters and Helm releases
```

## Validation Tools

| Tool | Purpose | Task |
|------|---------|------|
| `tofu fmt` | OpenTofu formatting | `task tg:fmt` |
| `terragrunt hclfmt` | Terragrunt HCL formatting | `task tg:fmt` |
| `terragrunt validate` | Stack validation | `task tg:validate` |
| `kustomize build` | Kubernetes manifest rendering | `task k8s:render` |
| `helm template` | Helm chart rendering | `task k8s:render` |
| `kubeconform` | Kubernetes schema validation | Available in Brewfile |

## What Validation Catches

- **`task tg:fmt`**: Formatting inconsistencies, syntax errors in HCL
- **`task tg:validate`**: Invalid Terraform/OpenTofu configurations, missing variables, dependency issues
- **`task k8s:render`**: Invalid kustomizations, missing resources, Helm chart errors, template failures

## Testing Philosophy

- **Fail fast**: Run validation early and often during development
- **No partial validation**: Run ALL validation tasks, not just the ones you think are relevant
- **Errors are blockers**: If any validation fails, stop and fix before proceeding
- **Render is validation**: The `k8s:render` task builds all manifests - if it passes, the structure is valid

---

# OPERATIONS

## Task Commands

```bash
# Validation (run these first!)
task tg:fmt                        # Format all HCL files
task tg:validate                   # Validate all Terragrunt stacks
task k8s:render                    # Render all Kubernetes manifests

# Kubernetes
task k8s:render-cluster-<cluster>  # Render specific cluster
task k8s:get-kubeconfig-<cluster>  # Fetch kubeconfig from AWS SSM
task k8s:delete-terminated-pods    # Clean up failed/completed pods

# Hardware (IPMI)
task inv:power-on-<host>           # Power on via IPMI
task inv:power-off-<host>          # Power off via IPMI
task inv:status-<host>             # Check IPMI status
task inv:sol-activate-<host>       # Serial-over-LAN console

# Infrastructure - see infrastructure/CLAUDE.md for full details
task tg:plan-<stack>               # Plan changes
task tg:apply-<stack>              # Apply (REQUIRES HUMAN APPROVAL)
```

## Secrets Management
- Secrets stored in AWS SSM Parameter Store
- Retrieved via External Secrets Operator
- Path pattern: `/homelab/kubernetes/${cluster_name}/<secret-name>`
- Never commit secrets to git - use ExternalSecret resources

---

# CLUSTERS

| Name | Purpose | Hardware | Notes |
|------|---------|----------|-------|
| live | Production | node41-43 (Supermicro x86_64) | 3-node HA control plane |
| integration | Testing | node44 (Supermicro x86_64) | Single node |
| dev | Development | rpi4 (Pi CM4 ARM64) | ARM64, resource-constrained |
| staging | Staging | (inactive) | Reserved |

## Promotion Path
Changes flow: `dev` → `integration` → `staging` → `live`

Test on dev (ARM64 compatible), validate on integration (x86_64), then promote to live.
