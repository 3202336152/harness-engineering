#!/bin/bash

set -euo pipefail

PROJECT_NAME="$(basename "$(pwd)")"
DESCRIPTION="TODO: Add project description."
FORCE=0
DRY_RUN=0
STACK="unknown"
IS_GIT=0
SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATES_DIR="$SKILL_DIR/assets/templates"

CREATED_FILES=()
CREATED_DIRS=()
SKIPPED_FILES=()

append_array_json() {
  local first=1
  local item
  printf '['
  for item in "$@"; do
    if [ -z "$item" ]; then
      continue
    fi
    if [ "$first" -eq 0 ]; then
      printf ','
    fi
    first=0
    printf '"%s"' "$(json_escape "$item")"
  done
  printf ']'
}

json_escape() {
  local text="$1"
  text=${text//\\/\\\\}
  text=${text//\"/\\\"}
  text=${text//$'\n'/\\n}
  text=${text//$'\r'/\\r}
  text=${text//$'\t'/\\t}
  printf '%s' "$text"
}

append_tracked_array_json() {
  local array_name="$1"
  local length=0

  eval "length=\${#${array_name}[@]}"
  if [ "$length" -eq 0 ]; then
    printf '[]'
    return
  fi

  eval "append_array_json \"\${${array_name}[@]}\""
}

usage() {
  cat <<'EOF'
Usage: init-harness.sh [--project-name <name>] [--description <text>] [--force] [--dry-run]
EOF
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --project-name)
        PROJECT_NAME="${2:-}"
        shift 2
        ;;
      --description)
        DESCRIPTION="${2:-}"
        shift 2
        ;;
      --force)
        FORCE=1
        shift
        ;;
      --dry-run)
        DRY_RUN=1
        shift
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        printf 'Unknown argument: %s\n' "$1" >&2
        exit 1
        ;;
    esac
  done
}

detect_environment() {
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    IS_GIT=1
  else
    printf 'Warning: Not a git repository. Some features may be limited.\n' >&2
  fi

  if [ -f package.json ]; then
    STACK="node"
  elif [ -f pyproject.toml ] || [ -f setup.py ]; then
    STACK="python"
  elif [ -f go.mod ]; then
    STACK="go"
  elif [ -f Cargo.toml ]; then
    STACK="rust"
  else
    STACK="unknown"
  fi
}

stack_commands() {
  case "$STACK" in
    node)
      cat <<'EOF'
npm install          # Install dependencies
npm run dev          # Start development server
npm test             # Run tests
npm run lint         # Run lint checks
npm run typecheck    # Run type checks
npm run build        # Build project
EOF
      ;;
    python)
      cat <<'EOF'
python -m pip install -e .    # Install project
python -m pytest              # Run tests
ruff check .                  # Run lint checks
mypy .                        # Run type checks
EOF
      ;;
    go)
      cat <<'EOF'
go build ./...           # Build project
go test ./...            # Run tests
golangci-lint run        # Run lint checks
EOF
      ;;
    rust)
      cat <<'EOF'
cargo build              # Build project
cargo test               # Run tests
cargo clippy             # Run lint checks
EOF
      ;;
    *)
      cat <<'EOF'
<install-command>       # Install dependencies
<dev-command>           # Start development flow
<test-command>          # Run tests
<lint-command>          # Run lint checks
<typecheck-command>     # Run type checks
EOF
      ;;
  esac
}

test_command() {
  case "$STACK" in
    node) printf 'npm test' ;;
    python) printf 'python -m pytest' ;;
    go) printf 'go test ./...' ;;
    rust) printf 'cargo test' ;;
    *) printf '<test-command>' ;;
  esac
}

create_directories() {
  local dir
  for dir in \
    docs \
    docs/design-docs \
    docs/exec-plans/active \
    docs/exec-plans/completed \
    docs/exec-plans/tech-debt \
    docs/product-specs \
    docs/references \
    .github \
    .harness; do
    if [ "$DRY_RUN" -eq 1 ]; then
      CREATED_DIRS+=("$dir")
    else
      if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        CREATED_DIRS+=("$dir")
      fi
    fi
  done
}

render_template() {
  local template_file="$1"
  local target_file="$2"
  local content=""

  if [ -f "$target_file" ] && [ "$FORCE" -ne 1 ]; then
    SKIPPED_FILES+=("$target_file")
    return 0
  fi

  if [ ! -f "$template_file" ]; then
    printf 'Warning: Missing template %s\n' "$template_file" >&2
    return 0
  fi

  content="$(cat "$template_file")"
  content="${content//'{{PROJECT_NAME}}'/$PROJECT_NAME}"
  content="${content//'{{DESCRIPTION}}'/$DESCRIPTION}"
  content="${content//'{{STACK_COMMANDS}}'/$(stack_commands)}"
  content="${content//'{{TEST_COMMAND}}'/$(test_command)}"

  if [ "$DRY_RUN" -eq 0 ]; then
    printf '%s\n' "$content" > "$target_file"
  fi
  CREATED_FILES+=("$target_file")
}

generate_files() {
  render_template "$TEMPLATES_DIR/AGENTS.md.tpl" "AGENTS.md"
  render_template "$TEMPLATES_DIR/CLAUDE.md.tpl" "CLAUDE.md"
  render_template "$TEMPLATES_DIR/ARCHITECTURE.md.tpl" "docs/ARCHITECTURE.md"
  render_template "$TEMPLATES_DIR/CONVENTIONS.md.tpl" "docs/CONVENTIONS.md"
  render_template "$TEMPLATES_DIR/TESTING.md.tpl" "docs/TESTING.md"
  render_template "$TEMPLATES_DIR/SECURITY.md.tpl" "docs/SECURITY.md"
  render_template "$TEMPLATES_DIR/PR_TEMPLATE.md.tpl" ".github/PULL_REQUEST_TEMPLATE.md"
  render_template "$TEMPLATES_DIR/core-beliefs.md.tpl" "docs/design-docs/core-beliefs.md"
  render_template "$TEMPLATES_DIR/architecture.json.tpl" ".harness/architecture.json"
}

output_report() {
  printf '{'
  printf '"status":"success",'
  printf '"project":"%s",' "$(json_escape "$PROJECT_NAME")"
  printf '"created_files":'
  append_tracked_array_json "CREATED_FILES"
  printf ','
  printf '"created_dirs":'
  append_tracked_array_json "CREATED_DIRS"
  printf ','
  printf '"skipped_files":'
  append_tracked_array_json "SKIPPED_FILES"
  printf ','
  printf '"detected_stack":"%s",' "$(json_escape "$STACK")"
  printf '"next_steps":'
  append_array_json \
    "Edit AGENTS.md to add project-specific architecture details" \
    "Fill in docs/ARCHITECTURE.md with your system design" \
    "Define coding standards in docs/CONVENTIONS.md" \
    "Configure test commands in docs/TESTING.md" \
    "Add architecture linting to your CI pipeline"
  printf '}\n'
}

main() {
  parse_args "$@"
  detect_environment
  create_directories
  generate_files
  output_report
}

main "$@"
