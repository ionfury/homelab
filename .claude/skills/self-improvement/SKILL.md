---
name: self-improvement
description: |
  Capture user feedback and corrections to enhance repository documentation and skills.
  Transforms conversational feedback into persistent knowledge by updating the appropriate
  CLAUDE.md files, skills, or other documentation.

  Use when: (1) User provides a correction or clarification, (2) User says "remember this",
  (3) User provides feedback about how something should work, (4) After completing work where
  new patterns or knowledge were discovered, (5) User explicitly asks to update documentation.

  Triggers: "remember this", "update the skill", "add this to documentation", "you should know",
  "in the future", "always do", "never do", "that's wrong", "actually it should be",
  "/self-improvement", "capture this", "document this pattern", "add to CLAUDE.md"
user-invocable: false
---

# Self-Improvement Skill

Capture feedback and corrections to continuously enhance repository knowledge.

## Philosophy

Knowledge gained during work should be captured immediately, not lost. Documentation updates go hand-in-hand with the work that revealed them — include them in the current branch, not separate PRs.

## Execution Flow

### Phase 1: Classify the Feedback

See [references/classification.md](references/classification.md) for the full signal → classification → target mapping and decision tree for finding the right file.

Short summary: Corrections fix existing docs. New patterns go to module CLAUDE.md or skills. Anti-patterns go to root CLAUDE.md. Workflows with 5+ steps become skills.

### Phase 2: Confirm Before Applying

**Always use AskUserQuestion before making updates.** Present:
1. Classified feedback type and proposed target location
2. Preview of the proposed change
3. Alternatives if uncertain

### Phase 3: Apply Update

**CLAUDE.md update**: Read the file → find the appropriate section → add content maintaining existing style and structure.

**Skill update**: Read the existing SKILL.md → identify the relevant section → add or modify → update references if needed.

**New skill**: Create SKILL.md with proper frontmatter, add to the relevant agent's `skills:` list in `.claude/agents/`, add to `.claude/settings.json` allow list.

**Correction**: Find all occurrences of incorrect information → update each → verify no broken references result.

If uncertain about placement, ask rather than guess. If the target file doesn't exist, ask whether to create it or find an alternative location. If the update would be substantial (rewrites a section), preview the full change and consider whether it warrants a separate skill.

## Integration with PR Workflow

Documentation updates are part of the current work. Group related code and doc changes together in the same commits. Proactively suggest documentation updates for new patterns discovered during implementation.

## Proactive Invocation

Invoke this skill when:
- Completing implementation work where new patterns emerged
- The same concept has been explained twice (capture it)
- The user corrects an approach mid-task
- Undocumented behavior is discovered

## Cross-References

- [references/classification.md](references/classification.md) — Feedback classification table and target location decision tree
