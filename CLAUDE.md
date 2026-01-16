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

## DRY and Code Reuse

Don't Repeat Yourself. Duplication is technical debt:
- **Single source of truth**: Every piece of logic should exist in exactly one place
- **Compose, don't copy**: Build higher-level operations by calling lower-level ones
- **Refactor when duplicating**: If you're copying code, stop and extract it into a reusable component
- **Consistency through reuse**: Reusing code ensures consistent behavior across the system

---

# CHANGE MANAGEMENT & DEPLOYMENT

**The primary goal of all practices in this repository is to provide safe continuity of service for the live environment.**

Every process, validation step, and architectural decision exists to protect production stability. When in doubt, choose the option that minimizes risk to live.

## Branch-Based Development

All changes flow through pull requests:
- **All changes require PRs**: Direct commits to `main` are forbidden (branch protection enforced)
- **Validation gates**: PRs must pass all validation checks before merge
- **Review required**: No self-merging - changes require approval

## Environment Promotion Pipeline

The `main` branch represents the desired state for production. Merging to `main` triggers a staged rollout:

```
PR merged to main
       ↓
  integration cluster
  (automated deployment)
       ↓
  1-hour soak period
  (validation must remain green)
       ↓
  live cluster
  (automated promotion)
```

1. **Integration deployment**: Changes apply to `integration` immediately after merge
2. **Soak period**: Minimum 1-hour validation window on `integration`
3. **Automatic promotion**: If validation remains green after soak, changes automatically promote to `live`

## Environment Purposes

| Environment | Purpose | Deployment |
|-------------|---------|------------|
| `dev` | Manual testing and experimentation | Manual (not part of automated pipeline) |
| `integration` | Automated upgrade testing | Automatic on merge to `main` |
| `live` | Production workloads | Automatic after integration validation |

The `dev` cluster is intentionally outside the automated promotion pipeline. Use it for:
- Testing breaking changes before creating a PR
- Experimenting with new configurations
- Validating ARM64 compatibility

## Infrastructure Recovery

All machines are configured to PXE boot into Talos maintenance mode when no OS is installed. This enables:
- **Full cluster rebuilds**: Any cluster can be recreated from git state
- **Disaster recovery**: Failed nodes automatically enter recovery mode
- **Consistent provisioning**: No manual OS installation required

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

## Git Safety

- **NEVER** merge or commit directly to `main` - all changes require a PR with passing validation
- **NEVER** remove `.git/index.lock` or other git lock files - they exist for a reason
- **NEVER** use `git reset --hard` to undo commits after pushing
- **NEVER** use `git push --force` or `git push --force-with-lease` - always create new commits to fix mistakes
- **NEVER** commit to `main` when creating a PR - always create the branch first, then commit
- **Correct PR workflow**: `git checkout -b <branch>` → make changes → `git commit` → `git push -u origin <branch>` → `gh pr create`

## Kubernetes Safety

- **NEVER** use `kubectl --force --grace-period=0` or `--ignore-not-found` flags
- **NEVER** modify CRD definitions without understanding operator compatibility
- **NEVER** apply changes directly to the cluster - always use the GitOps approach through Flux
- **NEVER** hallucinate YAML fields - use `kubectl explain`, official docs, or YAML schema validation

## Verification

- **NEVER** guess resource names, strings, IPs, or values - VERIFY against source files
- **NEVER** skip validation steps (`task tg:fmt`, `task tg:validate-<stack>`) before committing
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
.taskfiles/              # Task runner definitions
  ├── inventory/         # IPMI/hardware management tasks
  ├── talos/             # Talos cluster operations
  ├── terragrunt/        # Infrastructure validation/deployment
  ├── worktree/          # Git worktree management
  └── renovate/          # Dependency update validation

infrastructure/          # Terragrunt/OpenTofu - provisions bare metal to Kubernetes
  ├── stacks/            # Cluster deployments (dev, integration, live)
  ├── units/             # Reusable Terragrunt units
  ├── modules/           # OpenTofu modules
  ├── inventory.hcl      # Hardware inventory (hosts, IPs, MACs, disks)
  ├── networking.hcl     # Network topology
  ├── versions.hcl       # Pinned tool versions
  └── accounts.hcl       # External service credentials

kubernetes/              # Flux GitOps - deploys workloads
  ├── clusters/          # Per-cluster Flux bootstrap configs
  │   └── integration/   # Integration cluster entry point
  └── platform/          # Centralized platform definition
      ├── helm-charts.yaml    # ResourceSet defining all Helm releases
      ├── namespaces.yaml     # ResourceSet defining all namespaces
      ├── resources.yaml      # ResourceSet for non-Helm Kustomizations
      ├── kustomization.yaml  # Generates ConfigMap from values
      └── values/             # Helm values files (one per chart)
```

## Development Environment

All required CLI tools are defined in the `Brewfile`. Install them with:

```bash
brew bundle
```

This installs: `gh`, `awscli`, `kubectl`, `helm`, `kustomize`, `flux`, `go-task`, `tgenv`, `tofuenv`, `talosctl`, `cilium-cli`, `hcl2json`, `jq`, `yq`, and other dependencies.

**Opinion**: Always install tools via Brewfile. Never install CLI tools manually - if a tool is missing, add it to the Brewfile first.

---

# KUBERNETES OPINIONS (Flux GitOps)

## Platform Structure

The Kubernetes platform uses **Flux ResourceSets** for centralized, declarative management. All Helm releases are defined in a single `helm-charts.yaml` file rather than scattered across directories.

### Key Files

| File | Purpose |
|------|---------|
| `kubernetes/platform/helm-charts.yaml` | ResourceSet defining all Helm releases with versions and dependencies |
| `kubernetes/platform/namespaces.yaml` | ResourceSet defining all namespaces |
| `kubernetes/platform/resources.yaml` | ResourceSet for non-Helm Kustomizations (configs, secrets, etc.) |
| `kubernetes/platform/values/<chart>.yaml` | Helm values for each chart |

### Adding a New Helm Release

1. Add entry to `helm-charts.yaml` with name, namespace, chart details, and dependencies
2. Create `values/<chart-name>.yaml` with Helm values
3. Add the values file to `kustomization.yaml` configMapGenerator
4. If the chart needs post-install resources, add entry to `resources.yaml`

### ResourceSet Pattern

Helm releases are defined as inputs to a ResourceSet, which generates HelmRelease and HelmRepository resources:

```yaml
# In helm-charts.yaml
inputs:
  - name: "grafana"
    namespace: "monitoring"
    chart:
      name: "grafana"
      version: "8.8.5"
      url: "https://grafana.github.io/helm-charts"
    dependsOn: [kube-prometheus-stack]
```

**Opinion**:
- Chart versions are defined in `helm-charts.yaml`, NOT in values files
- Dependencies between releases use `dependsOn` arrays
- Values files contain only Helm chart configuration

## Variable Substitution

Flux performs variable substitution at reconciliation time. Use these patterns:

```yaml
# Simple substitution
url: https://grafana.${internal_domain}

# Cluster-specific (set in cluster-vars ConfigMap)
cluster: ${cluster_name}
```

**Available variables** (from cluster config):
- `${internal_domain}` - Internal TLD (e.g., internal.tomnowak.work)
- `${external_domain}` - External TLD
- `${cluster_name}` - Cluster name (dev, integration, live)
- `${cluster_id}` - Numeric cluster ID

**Opinion**: Never hardcode domains or cluster names. Always use substitution.

---

# CODE STYLE

## YAML (Kubernetes)
- Include schema comment: `# yaml-language-server: $schema=...`
- Use `---` document separator at file start
- 2-space indentation
- Quote strings that could be misinterpreted (especially "true"/"false")

## HCL (Terragrunt/OpenTofu)
- Use `hcl2json` + `jq` for scripted access to HCL data (e.g., inventory lookups)
- Format with `task tg:fmt` before committing

## Naming Conventions
| Resource | Convention | Example |
|----------|------------|---------|
| Helm release name | kebab-case, matches chart | `kube-prometheus-stack` |
| Namespace | kebab-case | `longhorn-system` |
| Values file | kebab-case, matches release | `values/grafana.yaml` |
| Task names | namespace:action-target | `talos:maint-node41` |

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

# 2. Run module tests (for specific module)
task tg:test-<module>              # Runs OpenTofu native tests

# 3. Validate infrastructure (for specific stack)
task tg:validate-<stack>           # Validates Terragrunt stack
```

## Validation Tools

| Tool | Purpose | Task |
|------|---------|------|
| `tofu fmt` | OpenTofu formatting | `task tg:fmt` |
| `terragrunt hclfmt` | Terragrunt HCL formatting | `task tg:fmt` |
| `terragrunt validate` | Stack validation | `task tg:validate-<stack>` |
| `kubeconform` | Kubernetes schema validation | Available in Brewfile |

## Testing Philosophy

- **Fail fast**: Run validation early and often during development
- **Errors are blockers**: If any validation fails, stop and fix before proceeding

---

# OPERATIONS

## Task Commands

```bash
# Validation
task tg:fmt                        # Format all HCL files
task tg:test-<module>              # Run tests for specific module
task tg:validate-<stack>           # Validate specific stack

# Infrastructure
task tg:list                       # List all stacks
task tg:gen-<stack>                # Generate stack from units
task tg:plan-<stack>               # Plan changes
task tg:apply-<stack>              # Apply (REQUIRES HUMAN APPROVAL)
task tg:clean-<stack>              # Clean stack cache

# Talos
task talos:maint                   # Check maintenance mode for all hosts
task talos:maint-<host>            # Check maintenance mode for specific host

# Hardware (IPMI)
task inv:hosts                     # List all hosts
task inv:power-status              # Power status for all hosts
task inv:power-on-<host>           # Power on via IPMI
task inv:power-off-<host>          # Power off via IPMI
task inv:power-cycle-<host>        # Power cycle via IPMI
task inv:status-<host>             # Check IPMI status
task inv:sol-activate-<host>       # Serial-over-LAN console

# Worktrees
task wt:list                       # List all worktrees
task wt:new                        # Create worktree for isolated work
task wt:remove                     # Remove worktree
task wt:resume                     # Resume Claude Code in worktree

# Renovate
task renovate:validate             # Validate Renovate config
```

## Secrets Management
- Secrets stored in AWS SSM Parameter Store
- Retrieved via External Secrets Operator
- Path pattern: `/homelab/kubernetes/${cluster_name}/<secret-name>`
- Never commit secrets to git - use ExternalSecret resources

### Required SSM Parameters for New Clusters

When bootstrapping a new cluster, populate these SSM parameters before the cluster can function fully:

| SSM Path | Description | Format |
|----------|-------------|--------|
| `/homelab/kubernetes/<cluster>/cloudflare-api-token` | Cloudflare API token for DNS challenges | JSON: `{"token": "<value>"}` |
| `/homelab/kubernetes/<cluster>/discord-webhook-secret` | Discord webhook URL for Alertmanager | Plain string: webhook URL |

**Bootstrap-managed secrets** (created by Terragrunt in kube-system):
- `external-secrets-access-key` - AWS IAM credentials for External Secrets Operator
- `heartbeat-ping-url` - Healthchecks.io ping URL (dynamically created per cluster)
- `flux-system` - GitHub token for Flux GitOps

**ExternalSecret-managed secrets** (synced from AWS SSM):
- `cloudflare-api-token` (cert-manager) - DNS challenge credentials
- `alertmanager-discord-webhook` (monitoring) - Discord notifications

## Inventory Lookups

Use `hcl2json` + `jq` to query inventory data:

```bash
# Get IP for a host
hcl2json < infrastructure/inventory.hcl | jq -r '.locals[0].hosts.node41.interfaces[0].addresses[0].ip'

# List all hosts
hcl2json < infrastructure/inventory.hcl | jq -r '.locals[0].hosts | keys[]'

# Get hosts in a cluster
hcl2json < infrastructure/inventory.hcl | jq -r '.locals[0].hosts | to_entries[] | select(.value.cluster == "live") | .key'
```

---

# CLUSTERS

| Name | Purpose | Hardware | Notes |
|------|---------|----------|-------|
| live | Production | node41-43 (Supermicro x86_64) | 3-node HA control plane |
| integration | Upgrade testing | node44 (Supermicro x86_64) | Single node, automated deployment |
| dev | Manual testing | rpi4, node46-48 (mixed ARM64/x86_64) | Multi-node, not in automated pipeline |

## Promotion Path

```
        dev (manual)              PR merged to main
             ↓                           ↓
    Create PR when ready    →    integration (auto)
                                         ↓
                                 1-hour soak period
                                         ↓
                                   live (auto)
```

- **dev**: Manual experimentation space - use to validate changes before creating a PR
- **integration**: Receives changes automatically when PRs merge to `main`
- **live**: Receives changes automatically after integration passes 1-hour validation soak
