#!/bin/bash

set -euo pipefail

first_existing_doc_path() {
  local path
  for path in "$@"; do
    [ -n "$path" ] || continue
    if [ -f "$path" ]; then
      printf '%s' "$path"
      return 0
    fi
  done
  return 1
}

project_doc_filename() {
  case "$1" in
    architecture) printf '项目架构.md' ;;
    design) printf '项目设计.md' ;;
    api-spec) printf '接口规范.md' ;;
    development) printf '开发规范.md' ;;
    requirements) printf '需求说明.md' ;;
    testing) printf '测试策略.md' ;;
    security) printf '安全规范.md' ;;
    operations) printf '运行基线.md' ;;
    observability) printf '可观测性基线.md' ;;
    architecture-index) printf '架构总览.md' ;;
    conventions-index) printf '开发约定.md' ;;
    testing-index) printf '测试入口.md' ;;
    security-index) printf '安全说明.md' ;;
    core-beliefs) printf '核心信念.md' ;;
    *)
      return 1
      ;;
  esac
}

project_doc_legacy_filename() {
  case "$1" in
    architecture) printf 'ARCHITECTURE.md' ;;
    design) printf 'DESIGN.md' ;;
    api-spec) printf 'API-SPEC.md' ;;
    development) printf 'DEVELOPMENT.md' ;;
    requirements) printf 'REQUIREMENTS.md' ;;
    testing) printf 'TESTING.md' ;;
    security) printf 'SECURITY.md' ;;
    operations) printf 'OPERATIONS.md' ;;
    observability) printf 'OBSERVABILITY.md' ;;
    architecture-index) printf 'ARCHITECTURE.md' ;;
    conventions-index) printf 'CONVENTIONS.md' ;;
    testing-index) printf 'TESTING.md' ;;
    security-index) printf 'SECURITY.md' ;;
    core-beliefs) printf 'core-beliefs.md' ;;
    *)
      return 1
      ;;
  esac
}

project_doc_path() {
  printf 'docs/project/%s' "$(project_doc_filename "$1")"
}

exec_plan_root_path() {
  printf '.harness/exec-plans'
}

exec_plan_dir_path() {
  printf '%s/%s' "$(exec_plan_root_path)" "$1"
}

product_specs_dir_path() {
  printf '.harness/product-specs'
}

project_references_dir_path() {
  printf '.harness/references'
}

project_index_doc_path() {
  printf 'docs/%s' "$(project_doc_filename "$1")"
}

design_doc_path() {
  printf 'docs/design-docs/%s' "$(project_doc_filename "$1")"
}

project_doc_id_from_path() {
  local name
  name="$(basename "$1")"

  case "$name" in
    '项目架构.md'|'ARCHITECTURE.md') printf 'architecture' ;;
    '项目设计.md'|'DESIGN.md') printf 'design' ;;
    '接口规范.md'|'API-SPEC.md') printf 'api-spec' ;;
    '开发规范.md'|'DEVELOPMENT.md') printf 'development' ;;
    '需求说明.md'|'REQUIREMENTS.md') printf 'requirements' ;;
    '测试策略.md'|'TESTING.md') printf 'testing' ;;
    '安全规范.md'|'SECURITY.md') printf 'security' ;;
    '运行基线.md'|'OPERATIONS.md') printf 'operations' ;;
    '可观测性基线.md'|'OBSERVABILITY.md') printf 'observability' ;;
    '架构总览.md') printf 'architecture-index' ;;
    '开发约定.md'|'CONVENTIONS.md') printf 'conventions-index' ;;
    '测试入口.md') printf 'testing-index' ;;
    '安全说明.md') printf 'security-index' ;;
    '核心信念.md'|'core-beliefs.md') printf 'core-beliefs' ;;
    *)
      return 1
      ;;
  esac
}

project_template_file_for_path() {
  case "$(project_doc_id_from_path "$1")" in
    core-beliefs) printf 'project/CORE-BELIEFS.md.tpl' ;;
    architecture) printf 'project/ARCHITECTURE.md.tpl' ;;
    design) printf 'project/DESIGN.md.tpl' ;;
    api-spec) printf 'project/API-SPEC.md.tpl' ;;
    development) printf 'project/DEVELOPMENT.md.tpl' ;;
    requirements) printf 'project/REQUIREMENTS.md.tpl' ;;
    testing) printf 'project/TESTING.md.tpl' ;;
    security) printf 'project/SECURITY.md.tpl' ;;
    operations) printf 'project/OPERATIONS.md.tpl' ;;
    observability) printf 'project/OBSERVABILITY.md.tpl' ;;
    *)
      return 1
      ;;
  esac
}

first_existing_project_doc() {
  case "$1" in
    architecture)
      first_existing_doc_path \
        "$(project_doc_path architecture)" \
        "docs/project/ARCHITECTURE.md" \
        "$(project_index_doc_path architecture-index)" \
        "docs/ARCHITECTURE.md"
      ;;
    design)
      first_existing_doc_path \
        "$(project_doc_path design)" \
        "docs/project/DESIGN.md"
      ;;
    api-spec)
      first_existing_doc_path \
        "$(project_doc_path api-spec)" \
        "docs/project/API-SPEC.md"
      ;;
    development)
      first_existing_doc_path \
        "$(project_doc_path development)" \
        "docs/project/DEVELOPMENT.md" \
        "$(project_index_doc_path conventions-index)" \
        "docs/CONVENTIONS.md"
      ;;
    requirements)
      first_existing_doc_path \
        "$(project_doc_path requirements)" \
        "docs/project/REQUIREMENTS.md"
      ;;
    testing)
      first_existing_doc_path \
        "$(project_doc_path testing)" \
        "docs/project/TESTING.md" \
        "$(project_index_doc_path testing-index)" \
        "docs/TESTING.md"
      ;;
    security)
      first_existing_doc_path \
        "$(project_doc_path security)" \
        "docs/project/SECURITY.md" \
        "$(project_index_doc_path security-index)" \
        "docs/SECURITY.md"
      ;;
    operations)
      first_existing_doc_path \
        "$(project_doc_path operations)" \
        "docs/project/OPERATIONS.md"
      ;;
    observability)
      first_existing_doc_path \
        "$(project_doc_path observability)" \
        "docs/project/OBSERVABILITY.md"
      ;;
    architecture-index)
      first_existing_doc_path \
        "$(project_index_doc_path architecture-index)" \
        "docs/ARCHITECTURE.md"
      ;;
    conventions-index)
      first_existing_doc_path \
        "$(project_index_doc_path conventions-index)" \
        "docs/CONVENTIONS.md"
      ;;
    testing-index)
      first_existing_doc_path \
        "$(project_index_doc_path testing-index)" \
        "docs/TESTING.md"
      ;;
    security-index)
      first_existing_doc_path \
        "$(project_index_doc_path security-index)" \
        "docs/SECURITY.md"
      ;;
    core-beliefs)
      first_existing_doc_path \
        "$(project_doc_path core-beliefs)" \
        "docs/project/core-beliefs.md" \
        "$(design_doc_path core-beliefs)" \
        "docs/design-docs/core-beliefs.md"
      ;;
    *)
      return 1
      ;;
  esac
}

first_existing_project_doc_by_path() {
  local doc_id=""

  if doc_id="$(project_doc_id_from_path "$1")"; then
    first_existing_project_doc "$doc_id"
  else
    first_existing_doc_path "$1"
  fi
}

feature_doc_filename() {
  case "$1" in
    overview) printf '功能概览.md' ;;
    design) printf '方案设计.md' ;;
    api-spec) printf '接口设计.md' ;;
    db-spec) printf '数据设计.md' ;;
    test-spec) printf '测试方案.md' ;;
    rollout) printf '发布回滚.md' ;;
    status) printf '状态.md' ;;
    *)
      return 1
      ;;
  esac
}

feature_doc_legacy_filename() {
  case "$1" in
    overview) printf 'overview.md' ;;
    design) printf 'design.md' ;;
    api-spec) printf 'api-spec.md' ;;
    db-spec) printf 'db-spec.md' ;;
    test-spec) printf 'test-spec.md' ;;
    rollout) printf 'rollout.md' ;;
    status) printf 'status.md' ;;
    *)
      return 1
      ;;
  esac
}

feature_doc_id_from_name() {
  local name
  name="$(basename "$1")"

  case "$name" in
    '功能概览.md'|'overview.md') printf 'overview' ;;
    '方案设计.md'|'design.md') printf 'design' ;;
    '接口设计.md'|'api-spec.md') printf 'api-spec' ;;
    '数据设计.md'|'db-spec.md') printf 'db-spec' ;;
    '测试方案.md'|'test-spec.md') printf 'test-spec' ;;
    '发布回滚.md'|'rollout.md') printf 'rollout' ;;
    '状态.md'|'status.md') printf 'status' ;;
    *)
      return 1
      ;;
  esac
}

canonical_feature_doc_name() {
  local doc_id=""

  if doc_id="$(feature_doc_id_from_name "$1")"; then
    feature_doc_filename "$doc_id"
  else
    printf '%s' "$(basename "$1")"
  fi
}

feature_doc_path() {
  local feature_dir="$1"
  local doc_id="$2"
  printf '%s/%s' "$feature_dir" "$(feature_doc_filename "$doc_id")"
}

first_existing_feature_doc() {
  local feature_dir="$1"
  local doc_id="$2"

  first_existing_doc_path \
    "$feature_dir/$(feature_doc_filename "$doc_id")" \
    "$feature_dir/$(feature_doc_legacy_filename "$doc_id")"
}

first_existing_feature_doc_by_name() {
  local feature_dir="$1"
  local doc_name="$2"
  local doc_id=""

  if doc_id="$(feature_doc_id_from_name "$doc_name")"; then
    first_existing_feature_doc "$feature_dir" "$doc_id"
  else
    first_existing_doc_path "$feature_dir/$doc_name"
  fi
}

feature_template_file_for_doc() {
  case "$(feature_doc_id_from_name "$1")" in
    overview) printf 'feature/overview.md.tpl' ;;
    design) printf 'feature/design.md.tpl' ;;
    api-spec) printf 'feature/api-spec.md.tpl' ;;
    db-spec) printf 'feature/db-spec.md.tpl' ;;
    test-spec) printf 'feature/test-spec.md.tpl' ;;
    rollout) printf 'feature/rollout.md.tpl' ;;
    status) printf 'feature/status.md.tpl' ;;
    *)
      return 1
      ;;
  esac
}
