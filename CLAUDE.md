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

## Continuous Improvement

Documentation and skills are living artifacts. Improve them proactively:
- **Learn from every task**: When completing work, identify patterns or knowledge that should be captured
- **Update documentation immediately**: If you discover something that should be in CLAUDE.md or a skill, update it as part of the current task
- **Capture user feedback**: When users provide corrections, preferences, or clarifications, encode them in the appropriate documentation
- **Use agent delegation**: Spawn specialized agents to update skills and documentation in parallel with primary work
- **Skills over repetition**: If you find yourself explaining the same concept twice, it belongs in a skill or CLAUDE.md

**When to update documentation:**
- New patterns discovered during implementation
- User corrections that reveal missing or incorrect guidance
- Repetitive explanations that could be codified
- Anti-patterns encountered that should be warned against
- Workflow improvements that benefit future tasks

**Documentation maintenance skills:**

| Skill | Purpose |
|-------|---------|
| `sync-claude` | Validate docs against codebase before commits |
| `self-improvement` | Capture corrections and new patterns immediately |

**Where does content belong?**
- **CLAUDE.md files**: Declarative knowledge (what exists, why, constraints)
- **Skills**: Procedural knowledge (step-by-step workflows)
- **Runbooks**: Emergency procedures (disaster recovery, incident response)

## Agent Orchestration

The main Claude agent operates as an **orchestrator**, not a direct executor. This maximizes context window efficiency and enables parallel work:

- **Delegate aggressively**: Use the Task tool to spawn specialized sub-agents for exploration, code review, architecture analysis, and implementation tasks
- **Preserve context**: The orchestrator's context is precious - offload research, file exploration, and deep dives to sub-agents
- **Use task lists**: For multi-step work, create a task list (TaskCreate) to track progress and maintain visibility
- **Clarify proactively**: Use AskUserQuestion liberally to validate assumptions, confirm approaches, and gather requirements before proceeding
- **Parallel execution**: Launch multiple sub-agents simultaneously when tasks are independent

**When to delegate vs execute directly:**

| Delegate to Sub-Agent | Execute Directly |
|-----------------------|------------------|
| Codebase exploration ("find all usages of X") | Single file reads you know the path to |
| Multi-file search patterns | Simple edits with clear requirements |
| Architecture investigation | Running known task commands |
| Code review | Quick validations |
| Implementation of isolated components | Clarification questions to user |

**Clarification is not overhead - it is a core competency.** Asking questions via `AskUserQuestion` saves context, prevents wasted work, and produces better outcomes. A wrong assumption can waste an entire agent's context window and require redoing work from scratch.

**ALWAYS ask when:**
- Multiple valid approaches exist and you're unsure which the user prefers
- The task scope is ambiguous or could be interpreted in meaningfully different ways
- You're about to make an architectural or design decision that constrains future options
- You encounter something unexpected (unfamiliar patterns, missing files, conflicting configs)
- You're unsure whether a change should be minimal or comprehensive
- Trade-offs exist between competing priorities (simplicity vs. flexibility, speed vs. correctness)
- Requirements are implicit - if you're inferring what the user wants rather than knowing, ask
- You're blocked and your next move is to guess

**NEVER silently assume when you can ask.** The user is your collaborator, not an obstacle. They have context you don't - about intent, priorities, constraints, and preferences. A 30-second question beats a 10-minute redo.

**How to ask well:**
- Present the options you've identified, not open-ended "what should I do?"
- Explain the trade-offs briefly so the user can make an informed choice
- Recommend an option when you have a reasoned preference (mark it as recommended)
- Batch related questions into a single `AskUserQuestion` call when possible

---

# NETWORK POLICY ENFORCEMENT

**All cluster network traffic is implicitly denied unless explicitly allowed.** This is enterprise-grade network segmentation using Cilium.

## Critical Knowledge for All Agents

| Fact | Impact |
|------|--------|
| Default deny is implicit | Pods cannot communicate unless a policy allows it |
| Application namespaces need labels | Without `network-policy.homelab/profile=<profile>`, apps have no ingress |
| Platform namespaces use custom CNPs | Never apply profiles to `kube-system`, `monitoring`, `database`, etc. |
| Troubleshoot with Hubble | `hubble observe --verdict DROPPED --namespace <ns>` shows blocked traffic |

## Namespace Profile Labels (Required for App Namespaces)

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: my-app
  labels:
    network-policy.homelab/profile: standard  # Choose: isolated, internal, internal-egress, standard
```

| Profile | Ingress | Egress | Use Case |
|---------|---------|--------|----------|
| `isolated` | None | DNS only | Batch jobs, workers |
| `internal` | Internal gateway | DNS only | Internal dashboards |
| `internal-egress` | Internal gateway | DNS + HTTPS | Internal apps calling external APIs |
| `standard` | Both gateways | DNS + HTTPS | Public-facing web apps |

## Shared Resource Access

Grant access to shared services via additional labels:

```bash
kubectl label namespace my-app access.network-policy.homelab/postgres=true    # Database access
kubectl label namespace my-app access.network-policy.homelab/dragonfly=true   # Dragonfly (Redis) access
kubectl label namespace my-app access.network-policy.homelab/garage-s3=true   # S3 storage
kubectl label namespace my-app access.network-policy.homelab/kube-api=true    # Kubernetes API
```

## Emergency Escape Hatch

If network policies block legitimate traffic:

```bash
# Disable enforcement (triggers alert after 5 minutes)
kubectl label namespace <ns> network-policy.homelab/enforcement=disabled

# Re-enable after fixing
kubectl label namespace <ns> network-policy.homelab/enforcement-
```

See `docs/runbooks/network-policy-escape-hatch.md` for full procedure.

## Detailed Documentation

For complete architecture, profiles, and debugging: [kubernetes/platform/config/network-policy/CLAUDE.md](kubernetes/platform/config/network-policy/CLAUDE.md)

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

The `main` branch represents the desired state for production. Merging to `main` triggers OCI artifact-based promotion:

```
PR merged to main
       ↓
  GHA builds OCI artifact
  (packages kubernetes/)
       ↓
  integration cluster
  (auto-deploys via ImagePolicy)
       ↓
  canary-checker validation
  (Flux health + platform checks)
       ↓
  GHA tags artifact as validated
       ↓
  live cluster
  (auto-deploys via ImagePolicy)
```

1. **Artifact build**: GHA packages `kubernetes/` directory as OCI artifact, tags as `integration-<sha>`
2. **Integration deployment**: Flux ImagePolicy auto-deploys artifacts matching `integration-*` pattern
3. **Validation**: canary-checker runs Flux health checks and platform smoke tests
4. **Promotion tag**: On validation success, GHA re-tags artifact as `validated-<sha>`
5. **Live deployment**: Flux ImagePolicy auto-deploys artifacts matching `validated-*` pattern

**Source types by cluster:**
- **dev**: Git-based (GitRepository) - for manual experimentation
- **integration/live**: OCI artifact-based (OCIRepository) - immutable promotion

## Infrastructure Recovery

All machines are configured to PXE boot into Talos maintenance mode when no OS is installed. This enables:
- **Full cluster rebuilds**: Any cluster can be recreated from git state
- **Disaster recovery**: Failed nodes automatically enter recovery mode
- **Consistent provisioning**: No manual OS installation required

## Pre-Commit Validation

**ALWAYS run validation before committing changes.** This catches issues locally before CI runs.

```bash
# For Kubernetes changes (kubernetes/, .github/workflows/)
task k8s:validate

# For infrastructure changes (infrastructure/)
task tg:fmt
task tg:test-<module>          # If you modified a module
task tg:validate-<stack>       # For the affected stack

# For Renovate config changes
task renovate:validate
```

**Validation is mandatory** - PRs will fail CI if validation doesn't pass. Running locally saves time and prevents broken commits.

---

## Dev Cluster Operations

For dev cluster permissions, pre-flight checks, and safety procedures, see [.taskfiles/CLAUDE.md](.taskfiles/CLAUDE.md#dev-cluster-safety).

| Cluster | Claude Permissions |
|---------|-------------------|
| `dev` | Plan, apply, destroy (with confirmation) |
| `integration` | Read-only, validation only |
| `live` | Read-only, validation only |

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
- **NEVER** skip validation steps before committing (see Pre-Commit Validation below)
- **NEVER** ignore deprecation warnings - implement migrations immediately
- **NEVER** silently assume user intent when multiple interpretations exist - use `AskUserQuestion` to clarify
- **NEVER** proceed with a guess when blocked - ask the user for guidance instead of inventing a workaround

## Test and Validation Failures

**Tests must be green. A skipped test is a broken test.**

**CRITICAL: NEVER dismiss ANY validation failure as "unrelated" or "minor".** Every failure has a cause that must be investigated. What appears unrelated often reveals tooling gaps, environment issues, or systemic problems.

When a test or validation fails:

1. **NEVER** skip, ignore, dismiss, or hand-wave ANY failure - not even "minor" ones
2. **NEVER** add `-skip`, `-ignore`, or similar flags as a first response
3. **NEVER** say a failure is "unrelated" without proving why and flagging it for follow-up
4. **ALWAYS** investigate the root cause using the "5 Whys" technique:
   - Why did the test fail? → Schema validation error
   - Why was the schema invalid? → Wrong field structure
   - Why was the structure wrong? → Misunderstood API spec
   - Why was it misunderstood? → Documentation unclear
   - Why? → Fix the actual code, not the test

5. **Fix the code, not the test** - if a test catches a real issue, the code is wrong
6. **Environment failures are still failures** - if a tool is missing, that's a Brewfile gap or setup issue that must be addressed
7. **Only as a LAST RESORT**: If after thorough investigation you believe the test itself is flawed (e.g., external schema is incorrect), use `AskUserQuestion` to get explicit approval before skipping

**Valid reasons to skip (require user approval):**
- External schema is demonstrably incorrect (provide evidence)
- Test infrastructure bug outside our control
- Temporary skip with tracked issue for follow-up

**Invalid reasons to skip:**
- "It works in the cluster"
- "The test is too strict"
- "It's just a warning"
- "It's unrelated to my change"
- "It's a minor issue"

## No Manual Steps — Everything Must Be Declarative

**This is a GitOps and Infrastructure-as-Code project. Manual operational tasks are forbidden.**

Every dependency an application needs — databases, S3 buckets, credentials, DNS records — must be provisioned declaratively through git-committed resources. If a resource can't be created through IaC, that's a gap to solve, not a step to defer.

- **NEVER** create resources with `PLACEHOLDER` values that require manual replacement
- **NEVER** list "manual operational tasks" or "post-merge steps" as follow-up work
- **NEVER** expect someone to run `kubectl`, call an API, or click a UI to complete a deployment
- **NEVER** defer provisioning of dependencies (databases, buckets, credentials) as separate manual work
- **ALWAYS** provision all dependencies declaratively: use CRDs (CNPG Cluster, GarageBucketClaim), ExternalSecret, secret-generator, or init containers
- **ALWAYS** ask (via `AskUserQuestion`) if you don't know how to declaratively provision a dependency — don't paper over it with placeholders

**The litmus test**: After merging a PR, does the system converge to a fully working state with zero human intervention? If not, the PR is incomplete.

## Documentation

- **NEVER** leave documentation stale after completing tasks - update CLAUDE.md, README, or runbooks as needed
- **NEVER** create summary docs about work performed - the git history is the record

---

# PHILOSOPHY

This repository pushes the boundaries of "infrastructure as code" - starting from BIOS configuration and ending at SLO dashboards. Every component is:
- **Declarative**: No manual steps, no imperative scripts
- **Reproducible**: Any cluster can be rebuilt from scratch in minutes
- **GitOps-driven**: Git is the source of truth, Flux reconciles state
- **Hands-off**: Once deployed, the system self-heals, self-updates, and self-upgrades (via Tuppr)
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

The `Brewfile` is the **definitive source** for all local CLI tooling. Every tool used in development, CI, or referenced in Taskfiles must be listed here.

```bash
brew bundle
```

**Rules:**
- **Brewfile is authoritative**: If a tool isn't in Brewfile, it shouldn't be assumed available
- **Add before using**: When introducing a new tool dependency, add it to Brewfile first
- **CI parity**: Tools used in CI workflows should have Brewfile equivalents for local development
- **No manual installs**: Never install CLI tools manually - always go through Brewfile

## Tool Version Management

Tool versions are managed by [mise](https://mise.jdx.dev/) via `.mise.toml`. This ensures CI and local development use identical versions.

### Setup

```bash
brew bundle              # Installs mise
mise trust               # Trust the .mise.toml config
mise install             # Install all tools at specified versions
eval "$(mise activate)"  # Add to shell profile for auto-activation
```

### Verify versions

```bash
mise current             # Show active tool versions
mise doctor              # Diagnose environment issues
```

### How it works

- `.mise.toml` defines pinned versions for development tools (helm, kustomize, kubeconform, yq, yamllint, task)
- Infrastructure tools (opentofu, terragrunt) defer to `.opentofu-version` and `.terragrunt-version` files
- CI workflows use `jdx/mise-action` to install the same versions
- Renovate auto-updates versions via the mise manager

## Platform Version Management

`kubernetes/platform/versions.env` is the **single source of truth** for all platform versions:

- **Infrastructure versions**: Talos, Kubernetes, Cilium (read by Terragrunt)
- **Helm chart versions**: All charts deployed via Flux (substituted at reconciliation)
- **Upgrade operations**: Tuppr reads versions for declarative upgrades
- **Dependency updates**: Renovate manages version bumps

See [kubernetes/platform/CLAUDE.md](kubernetes/platform/CLAUDE.md) for detailed version management patterns.

### Data Flow

```
kubernetes/platform/versions.env  ─────────────────────────────┐
    │                                                          │
    ├──→ infrastructure/stacks/*/  (Terragrunt reads versions) │
    │         │                                                │
    │         └──→ generates .cluster-vars.env per cluster     │
    │                    │                                     │
    │                    ▼                                     │
    │    kubernetes/clusters/<cluster>/.cluster-vars.env       │
    │                                                          │
    └──→ kubernetes/platform/ (Flux substitutes versions) ◄────┘
```

---

# DIRECTORY-SPECIFIC DOCUMENTATION

Each major directory has its own CLAUDE.md with domain-specific patterns:

| Directory | Focus |
|-----------|-------|
| [.github/CLAUDE.md](.github/CLAUDE.md) | CI/CD workflows, OCI artifact promotion pipeline |
| [.taskfiles/CLAUDE.md](.taskfiles/CLAUDE.md) | Task commands, dev cluster safety |
| [.claude/skills/CLAUDE.md](.claude/skills/CLAUDE.md) | Skill architecture and inventory |
| [docs/CLAUDE.md](docs/CLAUDE.md) | Runbook organization and guidelines |
| [infrastructure/CLAUDE.md](infrastructure/CLAUDE.md) | Architecture overview, testing philosophy |
| [infrastructure/stacks/CLAUDE.md](infrastructure/stacks/CLAUDE.md) | Stack lifecycles and definitions |
| [infrastructure/units/CLAUDE.md](infrastructure/units/CLAUDE.md) | Unit patterns and dependencies |
| [infrastructure/modules/CLAUDE.md](infrastructure/modules/CLAUDE.md) | Module development and testing |
| [kubernetes/platform/CLAUDE.md](kubernetes/platform/CLAUDE.md) | Flux patterns, secrets, version management |
| [kubernetes/platform/config/CLAUDE.md](kubernetes/platform/config/CLAUDE.md) | Config subsystem organization |
| [kubernetes/clusters/CLAUDE.md](kubernetes/clusters/CLAUDE.md) | Cluster configuration, promotion path |

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
| `loki` | Query Loki API for logs and debugging |
| `prometheus` | Query Prometheus API for metrics and alerts |
| `taskfiles` | Taskfile syntax and patterns |
| `sync-claude` | Validate and sync Claude docs before commits |
| `self-improvement` | Capture feedback to enhance documentation and skills |

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
| `network-policy-escape-hatch.md` | Disable network policies in emergencies |
| `network-policy-verification.md` | Verify network policy enforcement |
| `terragrunt-validation-state-issues.md` | Troubleshoot Terragrunt state validation failures |

**Knowledge types:**
- **Runbooks**: Procedural knowledge (step-by-step)
- **CLAUDE.md**: Declarative knowledge (how the system works)
- **Skills**: Investigative knowledge (how to debug)
