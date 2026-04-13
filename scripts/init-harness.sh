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
VENDORED_SKILL_ROOT="harness/.harness/skill-runtime/harness-engineering"
TEMPLATE_PACK_NAME="${TEMPLATE_PACK_NAME_DEFAULT:-harness-engineering-default}"
TEMPLATE_VERSION="${TEMPLATE_VERSION_DEFAULT:-1.1.0}"
TEMPLATE_LANGUAGE="${TEMPLATE_LANGUAGE_DEFAULT:-zh-CN}"
TEMPLATE_PROFILE=""
PROFILE_DESCRIPTION=""
ENTRY_TOOLS=()
CUSTOM_ENTRY_FILES=()
RESOLVED_ENTRY_FILES=()

# shellcheck source=scripts/lib/template-resolver.sh
. "$SCRIPT_DIR/lib/template-resolver.sh"
# shellcheck source=scripts/lib/template-profile.sh
. "$SCRIPT_DIR/lib/template-profile.sh"
# shellcheck source=scripts/lib/stack-detect.sh
. "$SCRIPT_DIR/lib/stack-detect.sh"
# shellcheck source=scripts/lib/doc-paths.sh
. "$SCRIPT_DIR/lib/doc-paths.sh"
# shellcheck source=scripts/lib/entry-docs.sh
. "$SCRIPT_DIR/lib/entry-docs.sh"

CREATED_FILES=()
CREATED_DIRS=()
SKIPPED_FILES=()
HYDRATION_REQUIRED_DOCS=()

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

architecture_src_roots_json() {
  local source_roots=()
  local path=""

  case "$TEMPLATE_PROFILE" in
    java-backend-service|java-batch-job|java-adapter)
      if [ "$STACK" = "java-maven" ] || [ "$STACK" = "java-gradle" ]; then
        while IFS= read -r path; do
          [ -n "$path" ] || continue
          source_roots+=("$path")
        done <<EOF
$(find . \
  \( -path './.git' -o -path './harness' -o -path './target' -o -path './build' -o -path './.build' -o -path './node_modules' \) -prune -o \
  -type d -path '*/src/main/java' -print | sed 's#^\./##' | sort -u)
EOF
      fi
      ;;
  esac

  if [ "${#source_roots[@]}" -eq 0 ]; then
    source_roots+=("$(architecture_src_root)")
  fi

  append_array_json "${source_roots[@]}"
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

profile_uses_java_hydration_gate() {
  case "$TEMPLATE_PROFILE" in
    java-backend-service|java-batch-job|java-adapter)
      return 0
      ;;
  esac
  return 1
}

strict_default_value() {
  if profile_uses_java_hydration_gate; then
    printf 'true'
  else
    printf 'false'
  fi
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
Usage: init-harness.sh [--project-name <name>] [--description <text>] [--template-root <path>] [--profile <name>] [--tool <name>] [--entry-file <path>] [--with-git-hook] [--with-husky] [--with-github-actions] [--with-strong-constraints] [--with-strict-spec-checks] [--force] [--dry-run]
EOF
}

trim_whitespace() {
  local value="$1"

  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

append_unique_value() {
  local value="$1"
  shift || true

  if [ -z "$value" ]; then
    return 0
  fi

  if [ "$#" -eq 0 ]; then
    return 0
  fi

  local item
  for item in "$@"; do
    if [ "$item" = "$value" ]; then
      return 1
    fi
  done
  return 0
}

append_csv_values_to_array() {
  local array_name="$1"
  local raw_values="$2"
  local values=()
  local value=""

  IFS=',' read -r -a values <<< "$raw_values"
  for value in "${values[@]}"; do
    value="$(trim_whitespace "$value")"
    [ -n "$value" ] || continue
    eval "$array_name+=(\"\$value\")"
  done
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
      --tool)
        append_csv_values_to_array "ENTRY_TOOLS" "${2:-}"
        shift 2
        ;;
      --entry-file)
        CUSTOM_ENTRY_FILES+=("${2:-}")
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

  if profile_uses_java_hydration_gate && { [ "$WITH_GIT_HOOK" -eq 1 ] || [ "$WITH_HUSKY" -eq 1 ]; } && [ "$WITH_STRICT_SPEC_CHECKS" -eq 0 ]; then
    WITH_STRICT_SPEC_CHECKS=1
  fi
}

append_resolved_entry_file() {
  local path="$1"

  path="$(trim_whitespace "$path")"
  [ -n "$path" ] || return 0
  if [ "${#RESOLVED_ENTRY_FILES[@]}" -eq 0 ] || append_unique_value "$path" "${RESOLVED_ENTRY_FILES[@]}"; then
    RESOLVED_ENTRY_FILES+=("$path")
  fi
}

entry_document_source_path() {
  local target_file="$1"
  local candidate=""

  for candidate in "${RESOLVED_ENTRY_FILES[@]-}"; do
    if [ "$candidate" != "$target_file" ] && [ -f "$candidate" ]; then
      printf '%s' "$candidate"
      return 0
    fi
  done

  candidate="$(first_existing_entry_document_path || true)"
  if [ -n "$candidate" ] && [ "$candidate" != "$target_file" ]; then
    printf '%s' "$candidate"
    return 0
  fi

  return 1
}

resolve_entry_documents() {
  local requested_tool=""
  local entry_file=""

  RESOLVED_ENTRY_FILES=()

  if [ "${#ENTRY_TOOLS[@]}" -eq 0 ] && [ "${#CUSTOM_ENTRY_FILES[@]}" -eq 0 ]; then
    while IFS= read -r entry_file; do
      append_resolved_entry_file "$entry_file"
    done <<EOF
$(default_entry_doc_files)
EOF
    return 0
  fi

  for requested_tool in "${ENTRY_TOOLS[@]-}"; do
    if ! entry_file="$(entry_doc_files_for_tool "$requested_tool" 2>/dev/null)"; then
      printf 'Unknown entry tool: %s\n' "$requested_tool" >&2
      printf 'Supported tools: codex, claude-code, gemini-cli, all\n' >&2
      exit 1
    fi

    while IFS= read -r entry_file; do
      append_resolved_entry_file "$entry_file"
    done <<EOF
$(entry_doc_files_for_tool "$requested_tool")
EOF
  done

  for entry_file in "${CUSTOM_ENTRY_FILES[@]-}"; do
    append_resolved_entry_file "$entry_file"
  done
}

detect_environment() {
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    IS_GIT=1
  else
    printf 'Warning: Not a git repository. Some features may be limited.\n' >&2
  fi

  STACK="$(detect_project_stack)"

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

append_hydration_required_doc() {
  local path="$1"

  [ -n "$path" ] || return 0
  if [ "${#HYDRATION_REQUIRED_DOCS[@]}" -eq 0 ] || append_unique_value "$path" "${HYDRATION_REQUIRED_DOCS[@]}"; then
    HYDRATION_REQUIRED_DOCS+=("$path")
  fi
}

project_hydration_doc_paths() {
  cat <<EOF
$(project_doc_path core-beliefs)
$(project_doc_path architecture)
$(project_doc_path design)
$(project_doc_path api-spec)
$(project_doc_path development)
$(project_doc_path requirements)
$(project_doc_path testing)
$(project_doc_path security)
$(project_doc_path operations)
$(project_doc_path observability)
EOF
}

collect_hydration_required_docs() {
  local path=""

  HYDRATION_REQUIRED_DOCS=()

  if [ "$DRY_RUN" -eq 1 ]; then
    while IFS= read -r path; do
      append_hydration_required_doc "$path"
    done <<EOF
$(project_hydration_doc_paths)
EOF
    return 0
  fi

  while IFS= read -r path; do
    [ -n "$path" ] || continue
    [ -f "$path" ] || continue
    if grep -Eq '^doc_state:[[:space:]]*scaffold([[:space:]]*)$' "$path" 2>/dev/null; then
      append_hydration_required_doc "$path"
    fi
  done <<EOF
$(project_hydration_doc_paths)
EOF
}

create_directories() {
  local dir
  for dir in \
    "$(harness_root_path)" \
    "$(harness_docs_root_path)" \
    "$(project_docs_dir_path)" \
    "$(feature_specs_root_path)" \
    "$(decisions_dir_path)" \
    .github \
    "$(harness_runtime_root_path)" \
    "$(exec_plan_dir_path active)" \
    "$(exec_plan_dir_path completed)" \
    "$(exec_plan_dir_path tech-debt)" \
    "$(product_specs_dir_path)" \
    "$(project_references_dir_path)" \
    "$(harness_runtime_root_path)/runtime" \
    "$(harness_runtime_root_path)/runtime/context" \
    "$(harness_runtime_root_path)/runs" \
    "$(harness_runtime_root_path)/evidence" \
    "$(harness_runtime_root_path)/metrics" \
    "$(harness_runtime_root_path)/migrations"; do
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
      "$(harness_runtime_root_path)/skill-runtime"; do
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
  content="${content//'{{STRICT_DEFAULT}}'/$(strict_default_value)}"
  content="${content//'{{PROFILE_DESCRIPTION}}'/$PROFILE_DESCRIPTION}"
  content="${content//'{{HARNESS_SKILL_ROOT}}'/$VENDORED_SKILL_ROOT}"
  content="${content//'{{HARNESS_VALIDATE_SPEC_FLAGS}}'/$(validate_spec_flags)}"
  content="${content//'{{ARCHITECTURE_LAYERS_JSON}}'/$(architecture_layers_json)}"
  content="${content//'{{ARCHITECTURE_LAYER_DIRECTION}}'/$(architecture_layer_direction)}"
  content="${content//'{{ARCHITECTURE_SRC_ROOT}}'/$(architecture_src_root)}"
  content="${content//'{{ARCHITECTURE_SRC_ROOTS_JSON}}'/$(architecture_src_roots_json)}"
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
  local target_file=""
  local source_file=""
  local content=""

  for target_file in "${RESOLVED_ENTRY_FILES[@]-}"; do
    if [ -f "$target_file" ] && [ "$FORCE" -ne 1 ]; then
      SKIPPED_FILES+=("$target_file")
      continue
    fi

    if [ "$FORCE" -ne 1 ]; then
      source_file="$(entry_document_source_path "$target_file" || true)"
    else
      source_file=""
    fi

    if [ -n "$source_file" ]; then
      content="$(cat "$source_file")"
      write_rendered_file "$target_file" "$content"
    else
      render_template "CLAUDE.md.tpl" "$target_file"
    fi
  done
}

runtime_bundle_copy_paths() {
  cat <<'EOF'
SKILL.md
LICENSE
assets/templates
assets/hooks
assets/ci-templates
schemas
scripts/audit-harness.sh
scripts/check-runtime-deps.sh
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
  local scan_path="harness/.harness/runtime/java-doc-scan.json"

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
  render_template "architecture.json.tpl" "harness/.harness/architecture.json"
  render_template "spec-policy.json.tpl" "harness/.harness/spec-policy.json"
  render_template "doc-impact-rules.json.tpl" "harness/.harness/doc-impact-rules.json"
  render_template "context-policy.json.tpl" "harness/.harness/context-policy.json"
  render_template "run-policy.json.tpl" "harness/.harness/run-policy.json"
  render_template "observability-policy.json.tpl" "harness/.harness/observability-policy.json"
  render_template "task-memory.json.tpl" "harness/.harness/runtime/task-memory.json"
  render_template "last-audit.json.tpl" "harness/.harness/runtime/last-audit.json"
  render_template "progress.md.tpl" "harness/.harness/runtime/progress.md"
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
  printf '"entry_files":'
  append_tracked_array_json "RESOLVED_ENTRY_FILES"
  printf ','
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
  printf '"hydration_required_count":%s,' "${#HYDRATION_REQUIRED_DOCS[@]}"
  printf '"hydration_required_docs":'
  append_tracked_array_json "HYDRATION_REQUIRED_DOCS"
  printf ','
  printf '"next_steps":'
  if [ "$java_stack_recommended" -eq 1 ] && [ "$WITH_STRONG_CONSTRAINTS" -eq 0 ] && [ "$WITH_GIT_HOOK" -eq 0 ] && [ "$WITH_HUSKY" -eq 0 ] && [ "$WITH_GITHUB_ACTIONS" -eq 0 ]; then
    append_array_json \
      "Treat any project doc that still has doc_state: scaffold as a template only; do not use it as project truth yet" \
      "After hydrating a project doc from real code, update its frontmatter from doc_state: scaffold to doc_state: hydrated" \
      "Use the hydration_required_docs list from this init output as the minimum project doc set that still needs real repository content" \
      "Review the generated entry doc(s) and add project-specific architecture details" \
      "Refresh the Java inventory with bash scripts/scan-java-project.sh --json before hydrating project docs after major code changes" \
      "After init, have the coding agent read key project files before filling harness/docs/project/; do not rely on guesses" \
      "Cover build files, entrypoints, package structure, representative adapters, core services, and application.yml before claiming project facts" \
      "Fill in $(project_doc_path architecture) and $(project_doc_path requirements) from observed code, and mark unknown areas as 待确认 or 未覆盖范围" \
      "Review harness/.harness/spec-policy.json to align required project-level and feature-level specs" \
      "Review harness/.harness/doc-impact-rules.json so code changes and doc updates can be gated together" \
      "Review harness/.harness/context-policy.json and harness/.harness/run-policy.json before enabling autonomous workflows" \
      "Review harness/.harness/observability-policy.json so logs, metrics, and traces can be captured into evidence bundles" \
      "Create your first feature spec with bash scripts/new-feature-spec.sh --id FEAT-001 --title \"Your feature\" --owner <name> --change-types <types>" \
      "Use bash scripts/harness-exec.sh prepare --task \"Your feature\" --feature-id FEAT-001 --title \"Your feature\" to generate plan and context together" \
      "For Java profiles, validate-spec now defaults to strict doc-state enforcement; scaffold docs will fail validation until hydrated" \
      "For Java projects, prefer rerunning init with --with-strong-constraints so local commits and CI can block spec drift automatically" \
      "Use bash scripts/migrate-template-docs.sh --json after template upgrades to back up and migrate historical docs" \
      "Run bash scripts/validate-spec.sh --json --strict after project docs are hydrated, then wire spec checks into CI" \
      "Add doc impact checks, architecture linting, spec validation, and harness GC to your CI pipeline"
  else
    append_array_json \
      "Treat any project doc that still has doc_state: scaffold as a template only; do not use it as project truth yet" \
      "After hydrating a project doc from real code, update its frontmatter from doc_state: scaffold to doc_state: hydrated" \
      "Use the hydration_required_docs list from this init output as the minimum project doc set that still needs real repository content" \
      "Review the generated entry doc(s) and add project-specific architecture details" \
      "$( [ "$java_stack_recommended" -eq 1 ] && printf '%s' 'Refresh the Java inventory with bash scripts/scan-java-project.sh --json before hydrating project docs after major code changes' )" \
      "After init, have the coding agent read key project files before filling harness/docs/project/; do not rely on guesses" \
      "Cover build files, entrypoints, package structure, representative adapters, core services, and application.yml before claiming project facts" \
      "Fill in $(project_doc_path architecture) and $(project_doc_path requirements) from observed code, and mark unknown areas as 待确认 or 未覆盖范围" \
      "Review harness/.harness/spec-policy.json to align required project-level and feature-level specs" \
      "Review harness/.harness/doc-impact-rules.json so code changes and doc updates can be gated together" \
      "Review harness/.harness/context-policy.json and harness/.harness/run-policy.json before enabling autonomous workflows" \
      "Review harness/.harness/observability-policy.json so logs, metrics, and traces can be captured into evidence bundles" \
      "Create your first feature spec with bash scripts/new-feature-spec.sh --id FEAT-001 --title \"Your feature\" --owner <name> --change-types <types>" \
      "Use bash scripts/harness-exec.sh prepare --task \"Your feature\" --feature-id FEAT-001 --title \"Your feature\" to generate plan and context together" \
      "$( [ "$java_stack_recommended" -eq 1 ] && printf '%s' 'For Java profiles, validate-spec now defaults to strict doc-state enforcement; scaffold docs will fail validation until hydrated' )" \
      "Use bash scripts/migrate-template-docs.sh --json after template upgrades to back up and migrate historical docs" \
      "Run bash scripts/validate-spec.sh --json --strict after project docs are hydrated, then wire spec checks into CI" \
      "Add doc impact checks, architecture linting, spec validation, and harness GC to your CI pipeline"
  fi
  printf '}\n'
}

main() {
  parse_args "$@"
  resolve_entry_documents
  init_template_resolver "$DEFAULT_TEMPLATES_DIR" "$USER_TEMPLATE_ROOT" "harness/.harness/templates"
  detect_environment
  prepare_guardrail_options
  create_directories
  generate_files
  collect_hydration_required_docs
  output_report
}

main "$@"
