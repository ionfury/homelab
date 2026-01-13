---
name: commit-commands
description: |
  Create git commits and pull requests following conventional commit styling and repository philosophy. Use when: (1) Creating commits after completing work, (2) Opening pull requests, (3) Writing commit messages that explain WHY changes were made, (4) Following the branch-based PR workflow. Emphasizes informative messages that connect changes to architecture and philosophy.
---

# Git Commits and Pull Requests

Create commits and PRs that explain WHY, not WHAT. The diff shows what changed—messages explain intent.

## Commit Format

```
<type>(<scope>): <description>

[optional body - explain WHY]

[optional footer]
```

**Rules:**
- Description: imperative present tense, lowercase first letter, no period
- Body: explain motivation and reasoning, not the changes themselves
- Footer: `BREAKING CHANGE:` for breaking changes, issue references

## Commit Types

| Type | Purpose | Increments |
|------|---------|------------|
| `feat` | Add/adjust/remove features | minor |
| `fix` | Bug fixes from prior feat commits | patch |
| `refactor` | Code rewrite without behavior change | patch |
| `perf` | Performance improvements | patch |
| `style` | Formatting without behavior change | - |
| `test` | Add or correct tests | - |
| `docs` | Documentation only | - |
| `build` | Build tools, dependencies, versions | - |
| `ops` | Infrastructure, deployment, monitoring | - |
| `chore` | Maintenance (.gitignore, initial commit) | - |
| `ci` | CI/CD pipeline changes | - |

## Scopes (This Repository)

| Scope | When to Use |
|-------|-------------|
| `k8s` | Kubernetes manifests, Flux, Helm releases |
| `infra` | Terragrunt, OpenTofu, modules, stacks |
| `apps` | Application workloads |
| `network` | Network policies, Cilium, UniFi |
| `storage` | Longhorn, PVCs, storage classes |
| `platform` | Cross-cutting platform concerns |
| `docs` | Documentation changes |

## Writing Good Commit Messages

**The diff shows WHAT. The message explains WHY.**

```bash
# BAD: Restates the diff
docs(docs): add CLAUDE.md with core principles section containing enterprise
at home philosophy and everything as code section and anti-patterns section

# BAD: Too vague
fix(k8s): fix bug

# GOOD: Explains intent concisely
docs(docs): add Claude Code context for repository conventions

# GOOD: With body for complex changes
feat(infra): add node50 to live cluster

Expanding capacity for increased workload from new monitoring stack.
```

**Message checklist:**
- [ ] Describes the contribution at a high level
- [ ] Explains WHY this change exists
- [ ] Does NOT enumerate files changed
- [ ] Does NOT restate what the diff shows
- [ ] Uses imperative mood ("add" not "added")

## Breaking Changes

Signal with `!` before the colon:

```bash
feat(infra)!: remove legacy network configuration

BREAKING CHANGE: Clusters must be on Cilium v1.15+ before applying.
Migration: Run `task tg:plan-live` to verify no disruption.
```

## Commit Workflow

1. **Gather context** (parallel):
   ```bash
   git status                    # See untracked/modified files
   git diff                      # Review staged + unstaged changes
   git log -5 --oneline          # See recent commit style
   ```

2. **Draft message**: Focus on WHY, connect to architecture

3. **Create commit**:
   ```bash
   git add <files>
   git commit -m "$(cat <<'EOF'
   type(scope): description

   Body explaining why this change was made.
   EOF
   )"
   ```

4. **Verify**: `git status` to confirm success

## Pull Request Format

```markdown
## Summary
<1-3 bullets explaining purpose and motivation>

## Test plan
<Checklist of verification steps>
```

**PR rules:**
- Summary explains intent, not file changes
- Don't enumerate modified files—reviewers see the diff
- Test plan has specific, actionable verification steps

### PR Examples

```markdown
# BAD: Restates the diff
## Summary
- Modified infrastructure/modules/talos/main.tf to add new variable
- Updated infrastructure/stacks/live/terragrunt.hcl to pass variable
- Changed kubernetes/clusters/base/monitoring/grafana.yaml version

# GOOD: Explains reasoning
## Summary
- Enable persistent storage for Grafana dashboards to survive pod restarts
- Upgrade Grafana to v10.x for new alerting features needed by on-call rotation

## Test plan
- [ ] Verify Grafana pod starts with PVC mounted
- [ ] Confirm existing dashboards load after pod restart
- [ ] Test new alerting rule creation in UI
```

## PR Workflow

1. **Create branch first** (never commit to main):
   ```bash
   git checkout -b feat/descriptive-name
   ```

2. **Gather context** (parallel):
   ```bash
   git status
   git diff
   git log main..HEAD --oneline   # Commits on this branch
   git diff main...HEAD           # All changes vs main
   ```

3. **Push and create PR**:
   ```bash
   git push -u origin HEAD
   gh pr create --title "type(scope): description" --body "$(cat <<'EOF'
   ## Summary
   - Bullet explaining why

   ## Test plan
   - [ ] Verification step
   EOF
   )"
   ```

## Git Safety Rules

**NEVER do these:**
- Commit directly to `main`—all changes require PRs
- Use `git push --force` or `--force-with-lease`
- Use `git reset --hard` after pushing
- Remove `.git/index.lock` files
- Use `-i` flags (interactive mode not supported)
- Skip hooks with `--no-verify`

**Amend rules** (only when ALL conditions met):
1. User explicitly requested, OR commit succeeded but pre-commit hook auto-modified files
2. HEAD commit was created by you in this conversation
3. Commit has NOT been pushed to remote

If commit failed or was rejected by hook: fix the issue and create a NEW commit.

## Repository Philosophy

This repository follows "Everything as Code"—if it's not in git, it doesn't exist.

**Connect changes to architecture:**
- Infrastructure changes → explain impact on dev/integration/live promotion
- Kubernetes changes → explain how it fits the GitOps model
- Module changes → explain the units→stacks→modules relationship

**No Claude signoff**: Do not include `Co-Authored-By: Claude` in commits.
