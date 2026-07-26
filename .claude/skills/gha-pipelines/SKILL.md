---
name: gha-pipelines
description: |
  Create and modify GitHub Actions CI/CD workflows for the homelab repository.
  Covers validation pipelines, OCI artifact promotion, and infrastructure testing.

  Use when: (1) Creating new GitHub Actions workflows, (2) Modifying existing CI/CD pipelines,
  (3) Adding validation or testing stages, (4) Debugging workflow failures.

  Triggers: "github actions", "workflow", "ci/cd", "pipeline", "gha",
  "build artifact", "validation workflow", "ci pipeline"
user-invocable: false
---

# GitHub Actions Pipelines

This repository uses `mise` for tool version management so CI and local dev use identical versions. Delegate to Taskfile commands, not raw CLI. Follow homelab-specific conventions below; for generic GHA patterns (matrix builds, github-script, action catalog), see the global [gha-pipelines skill](~/.claude/skills/gha-pipelines/SKILL.md).

## Core Patterns

**Tool setup** — always `jdx/mise-action@v3`, never `apt-get`/`brew`:
```yaml
steps:
  - uses: actions/checkout@v6
  - uses: jdx/mise-action@v3
  - run: task k8s:validate
```

**Actions reference:**

| Need | Action |
|------|--------|
| Checkout | `actions/checkout@v6` |
| Tool setup | `jdx/mise-action@v3` (reads `.mise.toml`) |
| GHCR login | `docker/login-action@v3` |
| GitHub API | `actions/github-script@v7` |
| Flux CLI | `fluxcd/flux2/action@v2` |

**Path-based triggers** — always include the workflow file itself and `.mise.toml`:
```yaml
on:
  pull_request:
    paths:
      - "kubernetes/**"
      - ".github/workflows/kubernetes-validate.yaml"
      - ".mise.toml"
      - ".taskfiles/kubernetes/**"
  workflow_dispatch:
```

**YAML schema comment** on every workflow file:
```yaml
---
# yaml-language-server: $schema=https://json.schemastore.org/github-workflow.json
```

**Permissions** — always minimal:
```yaml
permissions:
  contents: read
  packages: write   # Only when pushing to GHCR
  statuses: read    # Only when reading commit status events
```

## Workflow Inventory

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `kubernetes-validate.yaml` | PR (kubernetes/) | Lint, expand ResourceSets, build, template, kubeconform, pluto |
| `infrastructure-validate.yaml` | PR (infrastructure/) | Format checks, module tests (matrix per module) |
| `renovate-validate.yaml` | PR (renovate config) | Validate Renovate configuration |
| `build-platform-artifact.yaml` | Push to main (kubernetes/) | Build OCI artifact, tag for integration |
| `tag-validated-artifact.yaml` | Status event / manual | Promote validated artifact to stable semver |
| `renovate.yaml` | Scheduled (hourly) | Dependency update automation |
| `label-sync.yaml` | Scheduled / manual | Sync GitHub labels |

## OCI Promotion Pipeline

For full pipeline tracing and debugging, see the [promotion-pipeline skill](../promotion-pipeline/SKILL.md).

Key design decisions when modifying these workflows:
- Integration polls with `semver >= 0.0.0-0` (accepts `-rc.N`); live polls `>= 0.0.0` (stable only)
- `tag-validated-artifact` has idempotency guard — checks for existing `validated-*` tag before re-tagging (Flux Alerts fire on every reconciliation cycle)
- Build workflow queries GHCR for latest stable tag, bumps patch, creates next RC

## New Validation Workflow Template

```yaml
---
# yaml-language-server: $schema=https://json.schemastore.org/github-workflow.json
name: <Domain> Validate

on:
  pull_request:
    paths:
      - "<domain>/**"
      - ".github/workflows/<domain>-validate.yaml"
      - ".mise.toml"
  workflow_dispatch:

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - uses: jdx/mise-action@v3
      - run: task <domain>:validate
```

## Anti-Patterns

- **NEVER** install tools with `apt-get` or `brew` — use `mise`
- **NEVER** use raw `curl`/`jq` for GitHub API — use `actions/github-script`
- **NEVER** hardcode versions in workflow files — versions come from `.mise.toml` or `versions.env`
- **NEVER** use `permissions: write-all` — specify exact permissions needed
- **NEVER** skip `workflow_dispatch` — all workflows support manual runs

## Cross-References

- [.github/CLAUDE.md](../../.github/CLAUDE.md) — Declarative workflow architecture
- [promotion-pipeline skill](../promotion-pipeline/SKILL.md) — Debugging promotion failures
- [.taskfiles/CLAUDE.md](../../.taskfiles/CLAUDE.md) — Task commands used in workflows
