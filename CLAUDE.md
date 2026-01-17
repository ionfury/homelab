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
.taskfiles/              # Task runner definitions (see .taskfiles/CLAUDE.md)
infrastructure/          # Terragrunt/OpenTofu (see infrastructure/CLAUDE.md)
kubernetes/
  ├── clusters/          # Per-cluster bootstrap (see kubernetes/clusters/CLAUDE.md)
  └── platform/          # Centralized platform (see kubernetes/platform/CLAUDE.md)
```

## Development Environment

All required CLI tools are defined in the `Brewfile`. Install them with:

```bash
brew bundle
```

**Opinion**: Always install tools via Brewfile. Never install CLI tools manually - if a tool is missing, add it to the Brewfile first.

---

# DIRECTORY-SPECIFIC DOCUMENTATION

Each major directory has its own CLAUDE.md with domain-specific patterns:

| Directory | Focus |
|-----------|-------|
| [infrastructure/CLAUDE.md](infrastructure/CLAUDE.md) | Testing, validation, stacks, inventory lookups |
| [kubernetes/platform/CLAUDE.md](kubernetes/platform/CLAUDE.md) | Flux patterns, secrets management, variable substitution |
| [kubernetes/clusters/CLAUDE.md](kubernetes/clusters/CLAUDE.md) | Cluster configuration, promotion path |
| [.taskfiles/CLAUDE.md](.taskfiles/CLAUDE.md) | Task commands quick reference |

## Skills (Lazy-Loaded)

Invoke these skills for detailed procedural guidance:

| Skill | Trigger |
|-------|---------|
| `terragrunt` | Infrastructure operations, stack management |
| `opentofu-modules` | Module development and testing |
| `flux-gitops` | Adding Helm releases, ResourceSet patterns |
| `app-template` | Deploying apps with bjw-s/app-template |
| `kubesearch` | Researching Helm chart configurations |
| `k8s-sre` | Debugging Kubernetes incidents |
| `taskfiles` | Taskfile syntax and patterns |

---

# UNIVERSAL STANDARDS

## Documentation Philosophy

Code should be self-documenting. Comments and messages explain the WHY, not the WHAT.

**Guiding principles:**
- **Self-documenting code**: Use clear names, logical structure, and obvious patterns
- **Comments explain reasoning**: Why this approach? Why not the obvious alternative?
- **Omit the obvious**: Don't comment what the code clearly does
- **No redundancy**: If the code says it, don't repeat it in a comment

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

---

# RUNBOOKS

Operational runbooks for common procedures are in `docs/runbooks/`:

| Runbook | Purpose |
|---------|---------|
| `resize-volume.md` | Resize Longhorn volumes when automatic expansion fails |
| `supermicro-machine-setup.md` | Initial BIOS/IPMI configuration for new hardware |
| `longhorn-disaster-recovery.md` | Complete cluster recovery from S3 backups |

**Knowledge types:**
- **Runbooks**: Procedural knowledge (step-by-step)
- **CLAUDE.md**: Declarative knowledge (how the system works)
- **Skills**: Investigative knowledge (how to debug)
