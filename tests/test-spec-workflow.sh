#!/bin/bash

set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# shellcheck source=tests/test-helpers.sh
. "$REPO_ROOT/tests/test-helpers.sh"

describe "spec workflow"

it "creates feature-level spec documents from change types"
setup_test_dir
init_git_repo
bash "$REPO_ROOT/scripts/init-harness.sh" --project-name sample-app >/dev/null 2>&1
output=$(bash "$REPO_ROOT/scripts/new-feature-spec.sh" --id FEAT-001 --title "User Search" --owner alice --change-types api,db,rollout 2>&1)
status=$?
assert_success "$status" "feature spec command succeeds"
assert_file_exists "docs/features/FEAT-001-user-search/功能概览.md"
assert_file_exists "docs/features/FEAT-001-user-search/方案设计.md"
assert_file_exists "docs/features/FEAT-001-user-search/接口设计.md"
assert_file_exists "docs/features/FEAT-001-user-search/数据设计.md"
assert_file_exists "docs/features/FEAT-001-user-search/测试方案.md"
assert_file_exists "docs/features/FEAT-001-user-search/发布回滚.md"
assert_file_exists "docs/features/FEAT-001-user-search/状态.md"
assert_file_exists "docs/features/FEAT-001-user-search/manifest.json"
assert_file_contains "docs/features/FEAT-001-user-search/功能概览.md" "id: FEAT-001"
assert_file_contains "docs/features/FEAT-001-user-search/功能概览.md" "template_version: 1.1.0"
assert_file_contains "docs/features/FEAT-001-user-search/功能概览.md" "template_profile: generic"
assert_file_contains "docs/features/FEAT-001-user-search/功能概览.md" "# 功能概览"
assert_file_contains "docs/features/FEAT-001-user-search/功能概览.md" "## 业务背景与目标"
assert_file_contains "docs/features/FEAT-001-user-search/功能概览.md" "## 当前现状与边界"
assert_file_contains "docs/features/FEAT-001-user-search/功能概览.md" "## 上下游与依赖清单"
assert_file_contains "docs/features/FEAT-001-user-search/方案设计.md" "## 当前代码挂点与拟改动类"
assert_file_contains "docs/features/FEAT-001-user-search/方案设计.md" "## 主链路时序与处理步骤"
assert_file_contains "docs/features/FEAT-001-user-search/接口设计.md" "## 接口清单"
assert_file_contains "docs/features/FEAT-001-user-search/接口设计.md" "## 接口详细设计"
assert_file_contains "docs/features/FEAT-001-user-search/数据设计.md" "## DDL 与结构变更"
assert_file_contains "docs/features/FEAT-001-user-search/数据设计.md" "## 表与索引设计"
assert_file_contains "docs/features/FEAT-001-user-search/测试方案.md" "# 测试方案"
assert_file_contains "docs/features/FEAT-001-user-search/测试方案.md" "## 测试范围矩阵"
assert_file_contains "docs/features/FEAT-001-user-search/测试方案.md" "## 回归命令与证据"
assert_file_contains "docs/features/FEAT-001-user-search/发布回滚.md" "## 发布前检查"
assert_file_contains "docs/features/FEAT-001-user-search/发布回滚.md" "## 发布后观测指标"
assert_file_contains "docs/features/FEAT-001-user-search/状态.md" "## 当前状态"
assert_file_contains "docs/features/FEAT-001-user-search/状态.md" "## 本轮实现与剩余项"
assert_json_field "$(cat docs/features/FEAT-001-user-search/manifest.json)" ".feature_id" "FEAT-001"
assert_json_field "$(cat docs/features/FEAT-001-user-search/manifest.json)" '.required_docs | index("发布回滚.md") != null' "true"
assert_json_field "$(cat docs/features/FEAT-001-user-search/manifest.json)" ".rollback_required" "true"
assert_json_field "$output" ".status" "success"
assert_json_number_gte "$output" ".created_files | length" "8"
teardown_test_dir

it "validates a scaffolded project and feature spec set"
setup_test_dir
init_git_repo
bash "$REPO_ROOT/scripts/init-harness.sh" --project-name sample-app >/dev/null 2>&1
bash "$REPO_ROOT/scripts/new-feature-spec.sh" --id FEAT-002 --title "Billing Dashboard" --owner bob --change-types api >/dev/null 2>&1
output=$(bash "$REPO_ROOT/scripts/validate-spec.sh" --json 2>&1)
status=$?
assert_success "$status" "spec validation succeeds"
assert_json_field "$output" ".status" "passed"
assert_json_field "$output" ".project.missing_required_docs_count" "0"
assert_json_field "$output" ".features.invalid_count" "0"
teardown_test_dir

it "reports quality issues in strict mode for scaffolded placeholder content"
setup_test_dir
init_git_repo
bash "$REPO_ROOT/scripts/init-harness.sh" --project-name sample-app >/dev/null 2>&1
bash "$REPO_ROOT/scripts/new-feature-spec.sh" --id FEAT-STRICT-001 --title "Billing Dashboard" --owner bob --change-types api >/dev/null 2>&1
output=$(bash "$REPO_ROOT/scripts/validate-spec.sh" --json --strict 2>&1)
status=$?
assert_eq "1" "$status" "strict validation fails on placeholder content"
assert_json_field "$output" ".status" "invalid"
assert_json_field "$output" ".strict_mode" "true"
assert_json_number_gte "$output" ".quality.total_issue_count" "1"
teardown_test_dir

it "passes strict validation when required sections and metadata are complete"
setup_test_dir
init_git_repo
mkdir -p .harness docs/project docs/features/FEAT-100-custom
cat > .harness/spec-policy.json <<'EOF'
{
  "template_pack": {
    "name": "custom-pack",
    "version": "1.1.0",
    "profile": "java-backend-service",
    "language": "zh-CN"
  },
  "quality_gate": {
    "strict_default": false,
    "placeholder_patterns": ["TODO:", "待补充", "在这里", "请补充"]
  },
  "project_docs": [
    {
      "id": "architecture",
      "path": "docs/project/ARCHITECTURE.md",
      "required": true,
      "required_frontmatter": ["template_version", "template_profile"],
      "required_sections": ["## 系统上下文", "## 事务边界与一致性"]
    }
  ],
  "feature_spec": {
    "base_dir": "docs/features",
    "required_docs": ["overview.md"],
    "doc_rules": {
      "overview.md": {
        "required_frontmatter": ["template_version", "template_profile"],
        "required_sections": ["## 业务背景与目标", "## 验收标准"]
      }
    }
  }
}
EOF
cat > docs/project/ARCHITECTURE.md <<'EOF'
---
id: project-architecture
title: 项目架构
type: project-architecture
status: active
owner: team
last_updated: 2026-04-07
template_version: 1.1.0
template_profile: java-backend-service
---

# 项目架构

## 系统上下文

订单服务负责订单创建与状态流转。

## 事务边界与一致性

下单事务仅覆盖订单落库，消息通过 outbox 异步发送。
EOF
cat > docs/features/FEAT-100-custom/overview.md <<'EOF'
---
id: FEAT-100
title: 自定义能力
type: feature-overview
status: draft
owner: team
change_types: ""
last_updated: 2026-04-07
template_version: 1.1.0
template_profile: java-backend-service
---

# 功能概览

## 业务背景与目标

补充订单查询能力，减少客服人工排查时间。

## 验收标准

- [x] 支持按订单号查询。
EOF
output=$(bash "$REPO_ROOT/scripts/validate-spec.sh" --json --strict 2>&1)
status=$?
assert_success "$status" "strict validation succeeds for completed docs"
assert_json_field "$output" ".status" "passed"
assert_json_field "$output" ".strict_mode" "true"
assert_json_field "$output" ".quality.total_issue_count" "0"
teardown_test_dir

it "fails validation when a required feature spec is missing"
setup_test_dir
init_git_repo
bash "$REPO_ROOT/scripts/init-harness.sh" --project-name sample-app >/dev/null 2>&1
bash "$REPO_ROOT/scripts/new-feature-spec.sh" --id FEAT-003 --title "Search Filters" --owner carol --change-types api >/dev/null 2>&1
rm "docs/features/FEAT-003-search-filters/接口设计.md"
output=$(bash "$REPO_ROOT/scripts/validate-spec.sh" --json 2>&1)
status=$?
assert_eq "1" "$status" "spec validation fails when required docs are missing"
assert_json_field "$output" ".status" "invalid"
assert_json_field "$output" ".features.invalid_count" "1"
teardown_test_dir

it "writes a fix plan for missing feature docs"
setup_test_dir
init_git_repo
bash "$REPO_ROOT/scripts/init-harness.sh" --project-name sample-app >/dev/null 2>&1
bash "$REPO_ROOT/scripts/new-feature-spec.sh" --id FEAT-006 --title "Order Query" --owner frank --change-types api >/dev/null 2>&1
rm "docs/features/FEAT-006-order-query/接口设计.md"
output=$(bash "$REPO_ROOT/scripts/validate-spec.sh" --json --write-fix-plan .harness/fix-plan.json 2>&1)
status=$?
assert_eq "1" "$status" "spec validation still fails before autofix"
assert_file_exists ".harness/fix-plan.json"
assert_json_field "$(cat .harness/fix-plan.json)" ".status" "planned"
assert_json_field "$(cat .harness/fix-plan.json)" ".actions[0].action" "create_feature_doc"
teardown_test_dir

it "autofix-safe recreates missing feature docs from templates"
setup_test_dir
init_git_repo
bash "$REPO_ROOT/scripts/init-harness.sh" --project-name sample-app >/dev/null 2>&1
bash "$REPO_ROOT/scripts/new-feature-spec.sh" --id FEAT-007 --title "Order Query" --owner grace --change-types api >/dev/null 2>&1
rm "docs/features/FEAT-007-order-query/接口设计.md"
output=$(bash "$REPO_ROOT/scripts/validate-spec.sh" --json --autofix-safe 2>&1)
status=$?
assert_success "$status" "autofix-safe succeeds for missing feature docs"
assert_file_exists "docs/features/FEAT-007-order-query/接口设计.md"
assert_json_field "$output" ".status" "passed"
assert_json_number_gte "$output" ".autofix_count" "1"
teardown_test_dir

it "passes rollback readiness when rollout docs are present"
setup_test_dir
init_git_repo
bash "$REPO_ROOT/scripts/init-harness.sh" --project-name sample-app >/dev/null 2>&1
bash "$REPO_ROOT/scripts/new-feature-spec.sh" --id FEAT-008 --title "Order Query" --owner helen --change-types rollout >/dev/null 2>&1
output=$(bash "$REPO_ROOT/scripts/check-rollback-readiness.sh" --feature-id FEAT-008 --json 2>&1)
status=$?
assert_success "$status" "rollback readiness succeeds when rollout docs are complete"
assert_json_field "$output" ".status" "passed"
assert_json_field "$output" ".rollback_required" "true"
assert_json_field "$output" '.missing_items | length' "0"
teardown_test_dir

it "keeps Chinese feature titles as readable directory names"
setup_test_dir
init_git_repo
bash "$REPO_ROOT/scripts/init-harness.sh" --project-name sample-app >/dev/null 2>&1
output=$(bash "$REPO_ROOT/scripts/new-feature-spec.sh" --id FEAT-004 --title "用户 搜索" --owner dora --change-types api 2>&1)
status=$?
assert_success "$status" "feature spec command succeeds for Chinese title"
assert_file_exists "docs/features/FEAT-004-用户-搜索/功能概览.md"
assert_file_exists "docs/features/FEAT-004-用户-搜索/接口设计.md"
assert_file_exists "docs/features/FEAT-004-用户-搜索/manifest.json"
assert_file_contains "docs/features/FEAT-004-用户-搜索/功能概览.md" "title: 用户 搜索"
assert_json_field "$output" ".feature_dir" "docs/features/FEAT-004-用户-搜索"
teardown_test_dir

it "uses project-local template overrides for feature specs"
setup_test_dir
init_git_repo
bash "$REPO_ROOT/scripts/init-harness.sh" --project-name sample-app >/dev/null 2>&1
mkdir -p .harness/templates/feature
cat > .harness/templates/feature/overview.md.tpl <<'EOF'
---
id: {{FEATURE_ID}}
title: {{FEATURE_TITLE}}
type: feature-overview
status: draft
owner: {{OWNER}}
change_types: "{{CHANGE_TYPES}}"
last_updated: {{DATE}}
---

# 自定义功能概览

## 特殊要求

- 团队定制字段
EOF
output=$(bash "$REPO_ROOT/scripts/new-feature-spec.sh" --id FEAT-005 --title "Custom Search" --owner erin --change-types api 2>&1)
status=$?
assert_success "$status" "feature spec command succeeds with project template override"
assert_file_contains "docs/features/FEAT-005-custom-search/功能概览.md" "# 自定义功能概览"
assert_file_contains "docs/features/FEAT-005-custom-search/功能概览.md" "团队定制字段"
teardown_test_dir

print_summary
