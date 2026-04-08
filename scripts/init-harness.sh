#!/bin/bash

set -euo pipefail

PROJECT_NAME="$(basename "$(pwd)")"
DESCRIPTION="TODO: Add project description."
OWNER="team"
FORCE=0
DRY_RUN=0
STACK="unknown"
IS_GIT=0
TODAY="$(date +%F)"
SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEFAULT_TEMPLATES_DIR="$SKILL_DIR/assets/templates"
USER_TEMPLATE_ROOT="${HARNESS_TEMPLATE_ROOT:-}"
TEMPLATE_PACK_NAME="${TEMPLATE_PACK_NAME_DEFAULT:-harness-engineering-default}"
TEMPLATE_VERSION="${TEMPLATE_VERSION_DEFAULT:-1.1.0}"
TEMPLATE_LANGUAGE="${TEMPLATE_LANGUAGE_DEFAULT:-zh-CN}"
TEMPLATE_PROFILE=""
PROFILE_DESCRIPTION=""

# shellcheck source=scripts/lib/template-resolver.sh
. "$SCRIPT_DIR/lib/template-resolver.sh"
# shellcheck source=scripts/lib/template-profile.sh
. "$SCRIPT_DIR/lib/template-profile.sh"

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
Usage: init-harness.sh [--project-name <name>] [--description <text>] [--template-root <path>] [--profile <name>] [--force] [--dry-run]
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
      --template-root)
        USER_TEMPLATE_ROOT="${2:-}"
        shift 2
        ;;
      --profile)
        TEMPLATE_PROFILE="${2:-}"
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
  elif [ -f pom.xml ]; then
    STACK="java-maven"
  elif [ -f build.gradle ] || [ -f build.gradle.kts ]; then
    STACK="java-gradle"
  elif [ -f pyproject.toml ] || [ -f setup.py ]; then
    STACK="python"
  elif [ -f go.mod ]; then
    STACK="go"
  elif [ -f Cargo.toml ]; then
    STACK="rust"
  else
    STACK="unknown"
  fi

  if [ -z "$TEMPLATE_PROFILE" ]; then
    TEMPLATE_PROFILE="$(default_template_profile_for_stack "$STACK")"
  fi
  PROFILE_DESCRIPTION="$(describe_template_profile "$TEMPLATE_PROFILE")"
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
    java-maven)
      cat <<'EOF'
./mvnw clean compile              # Compile project
./mvnw spring-boot:run            # Start local application
./mvnw clean test                 # Run tests
./mvnw spotless:apply             # Format code
./mvnw -DskipTests package        # Build package
EOF
      ;;
    java-gradle)
      cat <<'EOF'
./gradlew classes                 # Compile project
./gradlew bootRun                 # Start local application
./gradlew clean test              # Run tests
./gradlew spotlessApply           # Format code
./gradlew build                   # Build package
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
    java-maven) printf './mvnw clean test' ;;
    java-gradle) printf './gradlew clean test' ;;
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
    docs/project \
    docs/features \
    docs/decisions \
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
  local logical_template="$1"
  local target_file="$2"
  local content=""
  local template_file=""

  if [ -f "$target_file" ] && [ "$FORCE" -ne 1 ]; then
    SKIPPED_FILES+=("$target_file")
    return 0
  fi

  if ! template_file="$(resolve_template_file "$logical_template")"; then
    printf 'Warning: Missing template %s\n' "$logical_template" >&2
    return 0
  fi

  content="$(cat "$template_file")"
  content="${content//'{{PROJECT_NAME}}'/$PROJECT_NAME}"
  content="${content//'{{DESCRIPTION}}'/$DESCRIPTION}"
  content="${content//'{{OWNER}}'/$OWNER}"
  content="${content//'{{DATE}}'/$TODAY}"
  content="${content//'{{STACK_COMMANDS}}'/$(stack_commands)}"
  content="${content//'{{TEST_COMMAND}}'/$(test_command)}"
  content="${content//'{{TEMPLATE_PACK_NAME}}'/$TEMPLATE_PACK_NAME}"
  content="${content//'{{TEMPLATE_VERSION}}'/$TEMPLATE_VERSION}"
  content="${content//'{{TEMPLATE_PROFILE}}'/$TEMPLATE_PROFILE}"
  content="${content//'{{TEMPLATE_LANGUAGE}}'/$TEMPLATE_LANGUAGE}"
  content="${content//'{{PROFILE_DESCRIPTION}}'/$PROFILE_DESCRIPTION}"

  if [ "$DRY_RUN" -eq 0 ]; then
    printf '%s\n' "$content" > "$target_file"
  fi
  CREATED_FILES+=("$target_file")
}

generate_files() {
  render_template "AGENTS.md.tpl" "AGENTS.md"
  render_template "CLAUDE.md.tpl" "CLAUDE.md"
  render_template "ARCHITECTURE.md.tpl" "docs/ARCHITECTURE.md"
  render_template "CONVENTIONS.md.tpl" "docs/CONVENTIONS.md"
  render_template "TESTING.md.tpl" "docs/TESTING.md"
  render_template "SECURITY.md.tpl" "docs/SECURITY.md"
  render_template "project/ARCHITECTURE.md.tpl" "docs/project/ARCHITECTURE.md"
  render_template "project/DESIGN.md.tpl" "docs/project/DESIGN.md"
  render_template "project/API-SPEC.md.tpl" "docs/project/API-SPEC.md"
  render_template "project/DEVELOPMENT.md.tpl" "docs/project/DEVELOPMENT.md"
  render_template "project/REQUIREMENTS.md.tpl" "docs/project/REQUIREMENTS.md"
  render_template "project/TESTING.md.tpl" "docs/project/TESTING.md"
  render_template "project/SECURITY.md.tpl" "docs/project/SECURITY.md"
  render_template "PR_TEMPLATE.md.tpl" ".github/PULL_REQUEST_TEMPLATE.md"
  render_template "core-beliefs.md.tpl" "docs/design-docs/core-beliefs.md"
  render_template "architecture.json.tpl" ".harness/architecture.json"
  render_template "spec-policy.json.tpl" ".harness/spec-policy.json"
  render_template "doc-impact-rules.json.tpl" ".harness/doc-impact-rules.json"
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
    "Fill in docs/project/ARCHITECTURE.md and docs/project/REQUIREMENTS.md with project-specific context" \
    "Review .harness/spec-policy.json to align required project-level and feature-level specs" \
    "Review .harness/doc-impact-rules.json so code changes and doc updates can be gated together" \
    "Create your first feature spec with bash scripts/new-feature-spec.sh --id FEAT-001 --title \"Your feature\" --owner <name> --change-types <types>" \
    "Run bash scripts/validate-spec.sh --json before wiring spec checks into CI" \
    "Add doc impact checks, architecture linting, and spec validation to your CI pipeline"
  printf '}\n'
}

main() {
  parse_args "$@"
  init_template_resolver "$DEFAULT_TEMPLATES_DIR" "$USER_TEMPLATE_ROOT" ".harness/templates"
  detect_environment
  create_directories
  generate_files
  output_report
}

main "$@"
