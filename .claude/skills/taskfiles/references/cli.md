# Task CLI Reference

Reference: https://taskfile.dev/reference/cli

## General

| Flag | Description |
|------|-------------|
| `-h, --help` | Display help |
| `--version` | Show version |
| `-v, --verbose` | Verbose output |
| `-s, --silent` | Disable command echoing |
| `--disable-fuzzy` | Disable fuzzy task name matching |

## Execution

| Flag | Description |
|------|-------------|
| `-f, --force` | Force run even if up-to-date |
| `-n, --dry` | Print commands without executing |
| `-p, --parallel` | Run tasks in parallel |
| `-C, --concurrency N` | Limit concurrent tasks (0 = unlimited) |
| `-F, --failfast` | Stop on first dependency failure |
| `-x, --exit-code` | Pass through exit code of failed commands |
| `-y, --yes` | Auto-confirm all prompts |

## File/Directory

| Flag | Description |
|------|-------------|
| `-d, --dir PATH` | Set working directory |
| `-t, --taskfile FILE` | Use custom Taskfile path |
| `-g, --global` | Use global `$HOME/Taskfile.yaml` |

## Output

| Flag | Description |
|------|-------------|
| `-o, --output MODE` | Output mode: interleaved, group, prefixed |
| `--output-group-begin TPL` | Template before grouped output |
| `--output-group-end TPL` | Template after grouped output |
| `--output-group-error-only` | Show output only on error |
| `-c, --color` | Enable colored output |

## Information

| Flag | Description |
|------|-------------|
| `-l, --list` | List tasks with descriptions |
| `-a, --list-all` | List all tasks (including internal) |
| `--summary` | Show detailed task info |
| `--status` | Check if tasks are up-to-date |
| `--json` | Output in JSON format |
| `--sort MODE` | Sort order: default, alphanumeric, none |

## Watch Mode

| Flag | Description |
|------|-------------|
| `-w, --watch` | Watch files and re-run on changes |
| `-I, --interval DUR` | Watch interval (default: 5s) |

## Initialization

| Flag | Description |
|------|-------------|
| `-i, --init` | Create new Taskfile.yaml |

## Common Usage

```bash
# List available tasks
task --list

# Run specific task
task build

# Run with arguments after --
task build -- --verbose

# Dry run
task deploy --dry

# Force re-run
task test --force

# Watch mode
task dev --watch

# Run tasks in parallel
task lint test --parallel

# Use alternate Taskfile
task -t ci/Taskfile.yaml build
```
