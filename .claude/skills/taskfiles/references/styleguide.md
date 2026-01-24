# Taskfile Style Guide

Reference: https://taskfile.dev/docs/styleguide

## Naming Conventions

### Variables
Use UPPERCASE exclusively:
```yaml
vars:
  BINARY_NAME: myapp          # correct
  binary_name: myapp          # avoid
```

### Task Names
Use kebab-case:
```yaml
tasks:
  do-something-fancy: ...     # correct
  do_something_fancy: ...     # avoid
```

### Namespaces
Use colons to separate namespace from task name:
```yaml
docker:build
docker:run
```

Namespacing occurs automatically with included Taskfiles.

### Template Variables
No whitespace around variable placeholders:
```yaml
cmds:
  - echo "{{.MESSAGE}}"       # correct
  - echo "{{ .MESSAGE }}"     # avoid
```

## File Organization

### Section Ordering
```yaml
version: "3"

includes:
  ...

# Optional configs (output, silent, method, run)
output: prefixed
silent: false

vars:
  ...

env:
  ...

# Or use dotenv instead of env
dotenv:
  - .env

tasks:
  ...
```

### Whitespace
- Separate main sections with blank lines
- Insert empty lines between task definitions

## Code Style

### Indentation
Use 2 spaces consistently. Avoid tabs or 4-space indentation.

### Complex Scripts
Prefer external scripts over multi-line commands:
```yaml
# Preferred
cmds:
  - ./scripts/complex_operation.sh

# Avoid for complex logic
cmds:
  - |
    if [ ... ]; then
      ...
    fi
```

## Script Extraction

When task logic exceeds simple commands, use this decision tree:

| Situation | Solution |
|-----------|----------|
| Single command | `cmd:` directive |
| Sequential independent commands | `cmds:` array |
| Iterating over a list | Task `for:` loops |
| Reusable parameterized operation | Internal helper task |
| Complex control flow, temp files, error handling | Extract to external script |

### Script Location Convention

Store extracted scripts alongside their taskfile:
```
.taskfiles/<namespace>/scripts/<task-name>.sh
```

### Script Standards

All extracted scripts must follow these standards:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Description: Brief description of what the script does
# Inputs: List environment variables the script expects
#   - VAR_NAME: description

# Script implementation...
```

### Reference Implementation

The `inventory/taskfile.yaml` demonstrates best practices:
- Uses `for:` loops for iteration
- Internal helper tasks for reusable operations
- No embedded heredocs

### When NOT to Extract

Keep logic inline when:
- It's a single pipeline or command
- It's 3-4 lines with no conditionals
- Extracting would add complexity without benefit

## Anti-Patterns

- Multi-line embedded command blocks
- Whitespace in variable templates
- Lowercase variable names
- Underscore-based task naming
- Inconsistent indentation
- Missing separating whitespace between sections
