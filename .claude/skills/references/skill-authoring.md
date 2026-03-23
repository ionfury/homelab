---
name: skill-authoring
description: Skill creation checklist, deprecation procedure, and maintenance guidance
type: reference
---

# Skill Authoring

## Creating a New Skill (7-Step Checklist)

1. Create directory: `.claude/skills/<skill-name>/`
2. Create `SKILL.md` with proper frontmatter
3. Add `references/` if supporting docs are needed
4. Add `scripts/` if automation helpers are useful
5. Add the skill to the relevant agent's `skills:` list in `.claude/agents/`
6. Add `Skill(<name>)` to `.claude/settings.json` allow list
7. Update `.claude/skills/CLAUDE.md` skill inventory (or `references/skill-inventory.md`)

## Skill Maintenance

### When to Update Skills

- When underlying systems change (API updates, new versions)
- When users report confusion or errors following procedures
- When better patterns are discovered
- When referenced paths, commands, or tools change

### Validation

Skills should be validated with the `sync-claude` skill, which checks:
- File/directory paths mentioned exist
- Commands referenced are valid
- Cross-references to other docs are accurate

## Deprecation Procedure

To deprecate a skill:
1. Add notice at top of SKILL.md: `**DEPRECATED**: Use [new-skill] instead`
2. Keep for one release cycle to allow transition
3. Remove directory after transition period
