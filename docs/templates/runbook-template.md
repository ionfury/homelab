# Runbook Template

## Template Structure

```markdown
# Runbook: <Title>

## Overview
Brief description of what this runbook addresses.

## Prerequisites
- Required access/permissions
- Required tools
- Required knowledge

## Procedure

### Step 1: <Action>
Specific commands and explanations.

### Step 2: <Action>
...

## Verification
How to confirm the procedure succeeded.

## Rollback (if applicable)
How to undo changes if something goes wrong.

## Related
Links to related runbooks, CLAUDE.md sections, or skills.
```

## Style Guidelines

- **Be explicit**: Include exact commands, not just descriptions
- **Warn about risks**: Call out destructive operations clearly
- **Include verification**: Every procedure should end with "how to confirm success"
- **Time estimates**: Include realistic time estimates for planning
- **Prerequisites first**: List what's needed before starting

## Naming Conventions

Pattern: `<topic>-<action>.md` (kebab-case)

| Good | Bad |
|------|-----|
| `resize-volume.md` | `ResizeVolume.md` |
| `longhorn-disaster-recovery.md` | `dr.md` |
| `network-policy-escape-hatch.md` | `net-pol-fix.md` |

## When to Create a Runbook

- Procedure involves **risk of data loss** or service disruption
- Procedure is **time-sensitive** (incident response)
- Procedure requires **specific sequence** of steps
- Procedure is **rarely performed** but critical when needed

## Adding a New Runbook

### Process

1. Create file: `docs/runbooks/<topic>-<action>.md`
2. Follow the template structure above
3. Include realistic time estimates
4. Add verification steps
5. Add to `docs/CLAUDE.md` runbooks table if appropriate
6. Test the procedure if possible

### Checklist

- [ ] Clear title describing the scenario
- [ ] Prerequisites listed
- [ ] Step-by-step commands (not just descriptions)
- [ ] Verification steps included
- [ ] Rollback procedure (if applicable)
- [ ] Time estimate in `docs/CLAUDE.md` table
