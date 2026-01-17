# Taskfile Schema Reference

Reference: https://taskfile.dev/docs/reference/schema

## Root-Level Properties

```yaml
version: "3"                      # Required: "3" or valid semver

includes:                         # Import external Taskfiles
  namespace: ./path/taskfile.yaml

output: interleaved               # Options: interleaved, group, prefixed
method: checksum                  # Options: checksum, timestamp, none
silent: false                     # Suppress command echoing
run: always                       # Options: always, once, when_changed
interval: 5s                      # Watch mode interval

vars:                             # Global variables
  VAR_NAME: value

env:                              # Global environment variables
  ENV_VAR: value

dotenv:                           # Load .env files
  - .env
  - .env.local

set: [pipefail]                   # POSIX shell options
shopt: [globstar]                 # Bash shell options

tasks:                            # Task definitions
  task-name: ...
```

## Include Properties

```yaml
includes:
  namespace:
    taskfile: ./path/taskfile.yaml
    dir: ./path                   # Working directory for included tasks
    optional: true                # Continue if file missing
    internal: true                # Mark all tasks as internal
    flatten: true                 # Remove namespace requirement
    excludes: [task1, task2]      # Exclude specific tasks
    vars:                         # Pass variables to included Taskfile
      VAR: value
```

## Task Properties

```yaml
tasks:
  task-name:
    desc: Short description       # Shown in --list
    summary: |                    # Shown with --summary
      Detailed description

    aliases: [alias1, alias2]     # Alternative names
    label: "custom-{{.VAR}}"      # Override display name

    dir: ./subdir                 # Execution directory
    silent: true                  # Suppress output
    internal: true                # Hide from --list

    deps:                         # Run before this task (parallel)
      - other-task
      - task: another-task
        vars: { VAR: value }

    cmds:                         # Commands to execute (sequential)
      - echo "hello"
      - task: subtask
        vars: { VAR: value }

    vars:                         # Task-level variables
      VAR: value
      DYNAMIC:
        sh: echo "computed"

    env:                          # Task-level environment
      MY_VAR: value

    sources:                      # Files to watch for changes
      - src/**/*.go
    generates:                    # Files produced by task
      - bin/app

    status:                       # Commands to check if task should run
      - test -f output.txt        # Exit 0 = up-to-date, skip task

    preconditions:                # Validate before running
      - sh: test -f required.txt
        msg: "required.txt is missing"

    requires:                     # Required variables
      vars: [VAR1, VAR2]

    prompt: "Are you sure?"       # Confirmation prompt

    platforms: [linux, darwin]    # Limit to specific OS/arch

    watch: true                   # Enable watch mode
    run: once                     # Execution behavior
```

## Command Properties

```yaml
cmds:
  # Simple command
  - echo "hello"

  # Task call with variables
  - task: other-task
    vars: { VAR: value }

  # Deferred (runs on exit, even on failure)
  - defer: rm -f temp.txt

  # For loops
  - for: [a, b, c]
    cmd: echo "{{.ITEM}}"

  - for:
      var: MY_LIST
    cmd: echo "{{.ITEM}}"

  - for:
      matrix:
        OS: [linux, darwin]
        ARCH: [amd64, arm64]
    cmd: echo "{{.ITEM.OS}}-{{.ITEM.ARCH}}"

  # Platform-specific
  - cmd: echo "unix"
    platforms: [linux, darwin]

  # Silent individual command
  - cmd: echo "quiet"
    silent: true
```

## Variable Types

```yaml
vars:
  # Static string
  STRING_VAR: "value"

  # Dynamic (shell command)
  DYNAMIC_VAR:
    sh: git rev-parse HEAD

  # Reference (preserves type for arrays/maps)
  REF_VAR:
    ref: .OTHER_VAR

  # Map
  MAP_VAR:
    key1: value1
    key2: value2
```

## Special Variables

| Variable | Description |
|----------|-------------|
| `{{.TASK}}` | Current task name |
| `{{.ROOT_DIR}}` | Root Taskfile directory |
| `{{.TASKFILE_DIR}}` | Current Taskfile directory |
| `{{.USER_WORKING_DIR}}` | Directory where task was invoked |
| `{{.MATCH}}` | Array of wildcard captures |
| `{{.CLI_ARGS}}` | Arguments after `--` |
| `{{.ITEM}}` | Current item in for loop |
| `{{.CHECKSUM}}` | Computed checksum (in status) |
| `{{.TIMESTAMP}}` | Computed timestamp (in status) |
| `{{.EXIT_CODE}}` | Exit code (in deferred commands) |

## Wildcard Tasks

```yaml
tasks:
  # Single wildcard
  build-*:
    vars:
      TARGET: "{{index .MATCH 0}}"
    cmds:
      - echo "Building {{.TARGET}}"

  # Multiple wildcards
  deploy-*-*:
    vars:
      ENV: "{{index .MATCH 0}}"
      APP: "{{index .MATCH 1}}"
    cmds:
      - echo "Deploying {{.APP}} to {{.ENV}}"
```
