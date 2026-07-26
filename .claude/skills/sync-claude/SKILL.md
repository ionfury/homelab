---
name: sync-claude
description: |
  Validate and synchronize Claude documentation (CLAUDE.md files and skills) against actual codebase state.
  Two modes: full (all docs) or changed (only docs affected by current branch, default).

  Use when: (1) Before creating a PR, (2) After changes that might invalidate doc claims,
  (3) Reviewing documentation for staleness.

  Triggers: "sync claude", "validate claude docs", "check documentation", "update CLAUDE.md",
  "before commit", "docs out of sync", "/sync-claude", "stale documentation"
user-invocable: false
---

# Claude Documentation Sync

Validate all Claude-related documentation before commits. Default mode is `changed` (branch-scoped); use `full` for exhaustive validation.

## Execution Flow

### Phase 1: Discovery

**Full mode**: Find all Claude docs in repository:
- `**/CLAUDE.md` (excluding `.terragrunt-cache/`, `.terragrunt-stack/`)
- `.claude/skills/*/SKILL.md`
- `.claude/skills/*/references/*.md`

**Changed mode**: Analyze branch diff:
1. Get changed files: `git diff --name-only origin/main...HEAD`
2. Find directly modified Claude docs
3. Find docs that reference changed paths (smart detection)

### Phase 2: Parallel Validation (Haiku Agents)

Spawn parallel Haiku agents organized by validation type:

#### Agent Group A: Path Validators (by directory)
One agent per major directory validates file/directory references:
- `infrastructure/` paths
- `kubernetes/` paths
- `.taskfiles/` paths
- Root and other paths

**Validation checks:**
- File paths mentioned exist: `[path/to/file](path/to/file)`
- Directory paths exist: `infrastructure/modules/`
- Glob patterns return results: `**/*.tf`

#### Agent Group B: Code Reference Validators
Validate code-level claims:
- Function/class names exist where documented
- Line number references are approximately accurate (±10 lines)
- Variable names in examples exist in referenced files

#### Agent Group C: Command Validators
Validate command examples:
- `task <name>` commands exist in Taskfile
- CLI tools referenced are in Brewfile
- Command syntax is valid (dry-run where safe)

#### Agent Group D: Cross-Reference Validators
Validate documentation consistency:
- Skill references in CLAUDE.md match actual skills
- Table entries match actual directories
- Runbook references exist

### Phase 3: Aggregation

Collect results from all agents into a unified report grouped by severity (CRITICAL / WARNING / INFO), showing doc path, line number, the broken reference, and a suggested fix. Count valid references. Present issues before proposing edits.

### Phase 4: Opus Validation

Spawn Opus agent to:
1. Review aggregated findings
2. Prioritize by impact (breaking vs cosmetic)
3. Generate proposed edits for each issue
4. Present final change list for approval

## Agent Responsibilities

Discovery Agent (Haiku): Use `discover-claude-docs.sh` (or `discover-claude-docs.sh --changed`) to enumerate files. For each file, run `extract-references.sh` to get path refs, dir refs, commands, skill refs, and CLI tools as structured JSON. Scripts are in `.claude/skills/sync-claude/scripts/`.

Path Validator Agents (Haiku, one per directory domain): Verify each path ref exists using Glob/Read. For misses, fuzzy-search for renames. Return valid/invalid lists with suggestions.

Command Validator Agent (Haiku): Verify `task <name>` commands exist in Taskfile.yaml or `.taskfiles/*`. Verify CLI tools appear in Brewfile. kubectl/git: syntax check only. Return valid/invalid with suggestions.

Change Impact Analyzer (Haiku, changed mode only): Parse `git diff --name-only origin/main...HEAD`. Find docs directly modified. Search all docs for references to changed paths/directories. Return impacted doc list.

Opus Validator Agent: Deduplicate all Haiku findings. Categorize severity (CRITICAL: broken refs users will hit; WARNING: outdated but functional; INFO: cosmetic). Generate proposed Edit operations (old_string/new_string). Present for user approval before applying.

## Mode Selection Logic

```
IF user specifies mode:
  USE specified mode
ELSE IF on main branch:
  USE full mode
ELSE IF branch has commits ahead of origin/main:
  USE changed mode
ELSE:
  USE full mode (no changes to analyze)
```

## Exclusions

Always exclude from scanning:
- `.terragrunt-cache/`
- `.terragrunt-stack/`
- `node_modules/`
- `.git/`
- `*.rendered/`

## Error Handling

If an agent fails:
1. Log the failure with context
2. Continue with other agents
3. Mark affected validations as "INCOMPLETE"
4. Include in final report for manual review
