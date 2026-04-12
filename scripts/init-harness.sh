#!/bin/bash

set -euo pipefail

PROJECT_NAME="$(basename "$(pwd)")"
DESCRIPTION="TODO: Add project description."
OWNER="team"
FORCE=0
DRY_RUN=0
WITH_GIT_HOOK=0
WITH_HUSKY=0
WITH_GITHUB_ACTIONS=0
WITH_STRONG_CONSTRAINTS=0
WITH_STRICT_SPEC_CHECKS=0
STACK="unknown"
IS_GIT=0
TODAY="$(date +%F)"
SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEFAULT_TEMPLATES_DIR="$SKILL_DIR/assets/templates"
USER_TEMPLATE_ROOT="${HARNESS_TEMPLATE_ROOT:-}"
VENDORED_SKILL_ROOT=".harness/skill-runtime/harness-engineering"
TEMPLATE_PACK_NAME="${TEMPLATE_PACK_NAME_DEFAULT:-harness-engineering-default}"
TEMPLATE_VERSION="${TEMPLATE_VERSION_DEFAULT:-1.1.0}"
TEMPLATE_LANGUAGE="${TEMPLATE_LANGUAGE_DEFAULT:-zh-CN}"
TEMPLATE_PROFILE=""
PROFILE_DESCRIPTION=""

# shellcheck source=scripts/lib/template-resolver.sh
. "$SCRIPT_DIR/lib/template-resolver.sh"
# shellcheck source=scripts/lib/template-profile.sh
. "$SCRIPT_DIR/lib/template-profile.sh"
# shellcheck source=scripts/lib/doc-paths.sh
. "$SCRIPT_DIR/lib/doc-paths.sh"

CREATED_FILES=()
CREATED_DIRS=()
SKIPPED_FILES=()

architecture_layers_json() {
  case "$TEMPLATE_PROFILE" in
    java-backend-service|java-batch-job|java-adapter)
      printf '["domain", "application", "infrastructure", "interfaces"]'
      ;;
    *)
      printf '["types", "config", "repo", "service", "runtime", "ui"]'
      ;;
  esac
}

architecture_layer_direction() {
  case "$TEMPLATE_PROFILE" in
    java-backend-service|java-batch-job|java-adapter)
      printf 'interfaces -> application -> domain; infrastructure -> domain'
      ;;
    *)
      printf 'left-to-right'
      ;;
  esac
}

architecture_src_root() {
  case "$TEMPLATE_PROFILE" in
    java-backend-service|java-batch-job|java-adapter)
      if [ "$STACK" = "java-maven" ] || [ "$STACK" = "java-gradle" ]; then
        printf 'src/main/java'
      else
        printf 'src'
      fi
      ;;
    *)
      printf 'src'
      ;;
  esac
}

architecture_package_conventions_json() {
  case "$TEMPLATE_PROFILE" in
    java-backend-service|java-batch-job|java-adapter)
      cat <<'EOF'
{
    "domain": "domain层：Entity、ValueObject、DomainService、Repository接口、DomainEvent",
    "application": "application层：ApplicationService、Command/Query、DTO、Assembler、事务边界",
    "infrastructure": "infrastructure层：RepositoryImpl、MQ Producer/Consumer、Cache、External HTTP Client、Mapper",
    "interfaces": "interfaces层：Controller、RPC Facade、Job、Listener、VO/Request/Response"
  }
EOF
      ;;
    *)
      printf '{}'
      ;;
  esac
}

architecture_cross_domain_via() {
  case "$TEMPLATE_PROFILE" in
    java-backend-service|java-batch-job|java-adapter)
      printf 'anti-corruption-layer'
      ;;
    *)
      printf 'providers'
      ;;
  esac
}

architecture_forbidden_dependencies_json() {
  case "$TEMPLATE_PROFILE" in
    java-backend-service|java-batch-job|java-adapter)
      cat <<'EOF'
[
    "domain -> infrastructure",
    "domain -> interfaces",
    "domain -> application",
    "application -> interfaces",
    "application -> infrastructure",
    "infrastructure -> interfaces",
    "infrastructure -> application"
  ]
EOF
      ;;
    *)
      printf '[]'
      ;;
  esac
}

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
Usage: init-harness.sh [--project-name <name>] [--description <text>] [--template-root <path>] [--profile <name>] [--with-git-hook] [--with-husky] [--with-github-actions] [--with-strong-constraints] [--with-strict-spec-checks] [--force] [--dry-run]
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
      --with-git-hook)
        WITH_GIT_HOOK=1
        shift
        ;;
      --with-husky)
        WITH_HUSKY=1
        shift
        ;;
      --with-github-actions)
        WITH_GITHUB_ACTIONS=1
        shift
        ;;
      --with-strong-constraints)
        WITH_STRONG_CONSTRAINTS=1
        shift
        ;;
      --with-strict-spec-checks)
        WITH_STRICT_SPEC_CHECKS=1
        shift
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

prepare_guardrail_options() {
  if [ "$WITH_STRONG_CONSTRAINTS" -eq 1 ]; then
    WITH_GIT_HOOK=1
    WITH_GITHUB_ACTIONS=1
    WITH_STRICT_SPEC_CHECKS=1
  fi
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

guardrails_requested() {
  [ "$WITH_GIT_HOOK" -eq 1 ] || [ "$WITH_HUSKY" -eq 1 ] || [ "$WITH_GITHUB_ACTIONS" -eq 1 ]
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

validate_spec_flags() {
  if [ "$WITH_STRICT_SPEC_CHECKS" -eq 1 ]; then
    printf '%s' '--json --strict'
  else
    printf '%s' '--json'
  fi
}

create_directories() {
  local dir
  for dir in \
    docs \
    docs/project \
    docs/features \
    docs/decisions \
    docs/exec-plans/active \
    docs/exec-plans/completed \
    docs/exec-plans/tech-debt \
    docs/product-specs \
    docs/references \
    .github \
    .harness \
    .harness/runtime \
    .harness/runtime/context \
    .harness/runs \
    .harness/evidence \
    .harness/metrics \
    .harness/migrations; do
    if [ "$DRY_RUN" -eq 1 ]; then
      CREATED_DIRS+=("$dir")
    else
      if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        CREATED_DIRS+=("$dir")
      fi
    fi
  done

  if guardrails_requested; then
    for dir in \
      .harness/skill-runtime; do
      if [ "$DRY_RUN" -eq 1 ]; then
        CREATED_DIRS+=("$dir")
      else
        if [ ! -d "$dir" ]; then
          mkdir -p "$dir"
          CREATED_DIRS+=("$dir")
        fi
      fi
    done
  fi

  if [ "$WITH_HUSKY" -eq 1 ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
      CREATED_DIRS+=(".husky")
    else
      if [ ! -d ".husky" ]; then
        mkdir -p ".husky"
        CREATED_DIRS+=(".husky")
      fi
    fi
  fi

  if [ "$WITH_GITHUB_ACTIONS" -eq 1 ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
      CREATED_DIRS+=(".github/workflows")
    else
      if [ ! -d ".github/workflows" ]; then
        mkdir -p ".github/workflows"
        CREATED_DIRS+=(".github/workflows")
      fi
    fi
  fi
}

render_content() {
  local content=""
  content="$1"
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
  content="${content//'{{HARNESS_SKILL_ROOT}}'/$VENDORED_SKILL_ROOT}"
  content="${content//'{{HARNESS_VALIDATE_SPEC_FLAGS}}'/$(validate_spec_flags)}"
  content="${content//'{{ARCHITECTURE_LAYERS_JSON}}'/$(architecture_layers_json)}"
  content="${content//'{{ARCHITECTURE_LAYER_DIRECTION}}'/$(architecture_layer_direction)}"
  content="${content//'{{ARCHITECTURE_SRC_ROOT}}'/$(architecture_src_root)}"
  content="${content//'{{ARCHITECTURE_PACKAGE_CONVENTIONS_JSON}}'/$(architecture_package_conventions_json)}"
  content="${content//'{{ARCHITECTURE_CROSS_DOMAIN_VIA}}'/$(architecture_cross_domain_via)}"
  content="${content//'{{ARCHITECTURE_FORBIDDEN_DEPENDENCIES_JSON}}'/$(architecture_forbidden_dependencies_json)}"

  printf '%s' "$content"
}

write_rendered_file() {
  local target_file="$1"
  local content="$2"

  if [ -f "$target_file" ] && [ "$FORCE" -ne 1 ]; then
    SKIPPED_FILES+=("$target_file")
    return 0
  fi

  if [ "$DRY_RUN" -eq 0 ]; then
    mkdir -p "$(dirname "$target_file")"
    printf '%s\n' "$content" > "$target_file"
  fi
  CREATED_FILES+=("$target_file")
}

render_template() {
  local logical_template="$1"
  local target_file="$2"
  local content=""
  local template_file=""

  if ! template_file="$(resolve_template_file "$logical_template")"; then
    printf 'Warning: Missing template %s\n' "$logical_template" >&2
    return 0
  fi

  content="$(render_content "$(cat "$template_file")")"
  write_rendered_file "$target_file" "$content"
}

render_support_template() {
  local source_file="$1"
  local target_file="$2"
  local content=""

  if [ ! -f "$source_file" ]; then
    printf 'Warning: Missing support template %s\n' "$source_file" >&2
    return 0
  fi

  content="$(render_content "$(cat "$source_file")")"
  write_rendered_file "$target_file" "$content"
}

render_entry_documents() {
  local agents_template=""

  render_template "CLAUDE.md.tpl" "CLAUDE.md"

  if agents_template="$(resolve_template_file "AGENTS.md.tpl" 2>/dev/null)"; then
    render_template "AGENTS.md.tpl" "AGENTS.md"
  else
    render_template "CLAUDE.md.tpl" "AGENTS.md"
  fi
}

runtime_bundle_copy_paths() {
  cat <<'EOF'
SKILL.md
LICENSE
assets/templates
assets/hooks
assets/ci-templates
scripts/audit-harness.sh
scripts/check-doc-freshness.sh
scripts/check-doc-impact.sh
scripts/check-rollback-readiness.sh
scripts/check-template-drift.sh
scripts/collect-runtime-evidence.sh
scripts/harness-exec.sh
scripts/harness-gc.sh
scripts/init-harness.sh
scripts/lint-architecture.sh
scripts/migrate-template-docs.sh
scripts/new-feature-spec.sh
scripts/plan-harness.sh
scripts/prepare-template-overrides.sh
scripts/resolve-task-context.sh
scripts/scan-java-project.sh
scripts/validate-spec.sh
scripts/lib
EOF
}

copy_runtime_entry() {
  local relative_path="$1"
  local source_path="$SKILL_DIR/$relative_path"
  local target_path="$VENDORED_SKILL_ROOT/$relative_path"
  local file_path=""

  [ -e "$source_path" ] || return 0

  if [ "$DRY_RUN" -eq 1 ]; then
    if [ -d "$source_path" ]; then
      while IFS= read -r file_path; do
        [ -n "$file_path" ] || continue
        CREATED_FILES+=("$VENDORED_SKILL_ROOT/${file_path#"$source_path"/}")
      done <<EOF
$(find "$source_path" -type f | sort)
EOF
    else
      CREATED_FILES+=("$target_path")
    fi
    return 0
  fi

  mkdir -p "$(dirname "$target_path")"
  cp -R "$source_path" "$target_path"

  if [ -d "$target_path" ]; then
    while IFS= read -r file_path; do
      [ -n "$file_path" ] || continue
      CREATED_FILES+=("$VENDORED_SKILL_ROOT/${file_path#./}")
    done <<EOF
$(cd "$VENDORED_SKILL_ROOT" && find "$relative_path" -type f | sort)
EOF
  else
    CREATED_FILES+=("$target_path")
  fi
}

vendor_runtime_bundle() {
  local relative_path=""

  if ! guardrails_requested; then
    return 0
  fi

  if [ -e "$VENDORED_SKILL_ROOT" ] && [ "$FORCE" -ne 1 ]; then
    SKIPPED_FILES+=("$VENDORED_SKILL_ROOT")
    return 0
  fi

  if [ "$DRY_RUN" -eq 0 ]; then
    rm -rf "$VENDORED_SKILL_ROOT"
    mkdir -p "$VENDORED_SKILL_ROOT"
    CREATED_DIRS+=("$VENDORED_SKILL_ROOT")
  else
    CREATED_DIRS+=("$VENDORED_SKILL_ROOT")
  fi

  while IFS= read -r relative_path; do
    [ -n "$relative_path" ] || continue
    copy_runtime_entry "$relative_path"
  done <<EOF
$(runtime_bundle_copy_paths)
EOF

  if [ "$DRY_RUN" -eq 0 ]; then
    find "$VENDORED_SKILL_ROOT" -name '.DS_Store' -type f -delete 2>/dev/null || true
  fi
}

make_executable_if_present() {
  local target_file="$1"
  if [ "$DRY_RUN" -eq 0 ] && [ -f "$target_file" ]; then
    chmod +x "$target_file"
  fi
}

generate_guardrails() {
  vendor_runtime_bundle

  if [ "$WITH_GIT_HOOK" -eq 1 ]; then
    if [ "$IS_GIT" -eq 1 ]; then
      render_support_template "$SKILL_DIR/assets/hooks/pre-commit-doc-guard.sh.tpl" ".git/hooks/pre-commit"
      make_executable_if_present ".git/hooks/pre-commit"
    else
      printf 'Warning: --with-git-hook requested outside a git repository; skipping git hook generation.\n' >&2
    fi
  fi

  if [ "$WITH_HUSKY" -eq 1 ]; then
    render_support_template "$SKILL_DIR/assets/hooks/pre-commit-doc-guard.sh.tpl" ".husky/pre-commit"
    make_executable_if_present ".husky/pre-commit"
    if [ "$DRY_RUN" -eq 0 ] && [ "$IS_GIT" -eq 1 ]; then
      git config core.hooksPath .husky
    fi
  fi

  if [ "$WITH_GITHUB_ACTIONS" -eq 1 ]; then
    render_support_template "$SKILL_DIR/assets/ci-templates/github-actions.yml.tpl" ".github/workflows/harness-guardrails.yml"
  fi
}

generate_java_scan_baseline() {
  local scan_path=".harness/runtime/java-doc-scan.json"

  if [ "$STACK" != "java-maven" ] && [ "$STACK" != "java-gradle" ]; then
    return 0
  fi

  if [ -f "$scan_path" ] && [ "$FORCE" -ne 1 ]; then
    SKIPPED_FILES+=("$scan_path")
    return 0
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    CREATED_FILES+=("$scan_path")
    return 0
  fi

  if bash "$SCRIPT_DIR/scan-java-project.sh" --output "$scan_path" --json >/dev/null 2>&1; then
    CREATED_FILES+=("$scan_path")
  else
    printf 'Warning: Failed to generate Java inventory baseline at %s\n' "$scan_path" >&2
  fi
}

generate_files() {
  render_entry_documents
  render_template "project/CORE-BELIEFS.md.tpl" "$(project_doc_path core-beliefs)"
  render_template "project/ARCHITECTURE.md.tpl" "$(project_doc_path architecture)"
  render_template "project/DESIGN.md.tpl" "$(project_doc_path design)"
  render_template "project/API-SPEC.md.tpl" "$(project_doc_path api-spec)"
  render_template "project/DEVELOPMENT.md.tpl" "$(project_doc_path development)"
  render_template "project/REQUIREMENTS.md.tpl" "$(project_doc_path requirements)"
  render_template "project/TESTING.md.tpl" "$(project_doc_path testing)"
  render_template "project/SECURITY.md.tpl" "$(project_doc_path security)"
  render_template "project/OPERATIONS.md.tpl" "$(project_doc_path operations)"
  render_template "project/OBSERVABILITY.md.tpl" "$(project_doc_path observability)"
  render_template "PR_TEMPLATE.md.tpl" ".github/PULL_REQUEST_TEMPLATE.md"
  render_template "architecture.json.tpl" ".harness/architecture.json"
  render_template "spec-policy.json.tpl" ".harness/spec-policy.json"
  render_template "doc-impact-rules.json.tpl" ".harness/doc-impact-rules.json"
  render_template "context-policy.json.tpl" ".harness/context-policy.json"
  render_template "run-policy.json.tpl" ".harness/run-policy.json"
  render_template "observability-policy.json.tpl" ".harness/observability-policy.json"
  render_template "task-memory.json.tpl" ".harness/runtime/task-memory.json"
  render_template "last-audit.json.tpl" ".harness/runtime/last-audit.json"
  render_template "progress.md.tpl" ".harness/runtime/progress.md"
  generate_java_scan_baseline
  generate_guardrails
}

output_report() {
  local enabled_guardrails=()
  local java_stack_recommended=0

  if [ "$WITH_GIT_HOOK" -eq 1 ]; then
    enabled_guardrails+=("git-hook")
  fi
  if [ "$WITH_HUSKY" -eq 1 ]; then
    enabled_guardrails+=("husky")
  fi
  if [ "$WITH_GITHUB_ACTIONS" -eq 1 ]; then
    enabled_guardrails+=("github-actions")
  fi
  if [ "$WITH_STRICT_SPEC_CHECKS" -eq 1 ]; then
    enabled_guardrails+=("strict-spec-checks")
  fi
  if [ "$STACK" = "java-maven" ] || [ "$STACK" = "java-gradle" ]; then
    java_stack_recommended=1
  fi

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
  printf '"enabled_guardrails":'
  append_array_json "${enabled_guardrails[@]-}"
  printf ','
  printf '"detected_stack":"%s",' "$(json_escape "$STACK")"
  printf '"next_steps":'
  if [ "$java_stack_recommended" -eq 1 ] && [ "$WITH_STRONG_CONSTRAINTS" -eq 0 ] && [ "$WITH_GIT_HOOK" -eq 0 ] && [ "$WITH_HUSKY" -eq 0 ] && [ "$WITH_GITHUB_ACTIONS" -eq 0 ]; then
    append_array_json \
      "Edit AGENTS.md to add project-specific architecture details" \
      "Refresh the Java inventory with bash scripts/scan-java-project.sh --json before hydrating project docs after major code changes" \
      "After init, have the coding agent read key project files before filling docs/project/; do not rely on guesses" \
      "Cover build files, entrypoints, package structure, representative adapters, core services, and application.yml before claiming project facts" \
      "Fill in $(project_doc_path architecture) and $(project_doc_path requirements) from observed code, and mark unknown areas as 待确认 or 未覆盖范围" \
      "Review .harness/spec-policy.json to align required project-level and feature-level specs" \
      "Review .harness/doc-impact-rules.json so code changes and doc updates can be gated together" \
      "Review .harness/context-policy.json and .harness/run-policy.json before enabling autonomous workflows" \
      "Review .harness/observability-policy.json so logs, metrics, and traces can be captured into evidence bundles" \
      "Create your first feature spec with bash scripts/new-feature-spec.sh --id FEAT-001 --title \"Your feature\" --owner <name> --change-types <types>" \
      "Use bash scripts/harness-exec.sh prepare --task \"Your feature\" --feature-id FEAT-001 --title \"Your feature\" to generate plan and context together" \
      "For Java projects, prefer rerunning init with --with-strong-constraints so local commits and CI can block spec drift automatically" \
      "Use bash scripts/migrate-template-docs.sh --json after template upgrades to back up and migrate historical docs" \
      "Run bash scripts/validate-spec.sh --json --strict after project docs are hydrated, then wire spec checks into CI" \
      "Add doc impact checks, architecture linting, spec validation, and harness GC to your CI pipeline"
  else
    append_array_json \
      "Edit AGENTS.md to add project-specific architecture details" \
      "$( [ "$java_stack_recommended" -eq 1 ] && printf '%s' 'Refresh the Java inventory with bash scripts/scan-java-project.sh --json before hydrating project docs after major code changes' )" \
      "After init, have the coding agent read key project files before filling docs/project/; do not rely on guesses" \
      "Cover build files, entrypoints, package structure, representative adapters, core services, and application.yml before claiming project facts" \
      "Fill in $(project_doc_path architecture) and $(project_doc_path requirements) from observed code, and mark unknown areas as 待确认 or 未覆盖范围" \
      "Review .harness/spec-policy.json to align required project-level and feature-level specs" \
      "Review .harness/doc-impact-rules.json so code changes and doc updates can be gated together" \
      "Review .harness/context-policy.json and .harness/run-policy.json before enabling autonomous workflows" \
      "Review .harness/observability-policy.json so logs, metrics, and traces can be captured into evidence bundles" \
      "Create your first feature spec with bash scripts/new-feature-spec.sh --id FEAT-001 --title \"Your feature\" --owner <name> --change-types <types>" \
      "Use bash scripts/harness-exec.sh prepare --task \"Your feature\" --feature-id FEAT-001 --title \"Your feature\" to generate plan and context together" \
      "Use bash scripts/migrate-template-docs.sh --json after template upgrades to back up and migrate historical docs" \
      "Run bash scripts/validate-spec.sh --json --strict after project docs are hydrated, then wire spec checks into CI" \
      "Add doc impact checks, architecture linting, spec validation, and harness GC to your CI pipeline"
  fi
  printf '}\n'
}

main() {
  parse_args "$@"
  prepare_guardrail_options
  init_template_resolver "$DEFAULT_TEMPLATES_DIR" "$USER_TEMPLATE_ROOT" ".harness/templates"
  detect_environment
  create_directories
  generate_files
  output_report
}

main "$@"
