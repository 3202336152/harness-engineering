#!/bin/bash

set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# shellcheck source=tests/test-helpers.sh
. "$REPO_ROOT/tests/test-helpers.sh"

describe "template governance"

it "lists the built-in templates available for override"
setup_test_dir
init_git_repo
output=$(bash "$REPO_ROOT/scripts/prepare-template-overrides.sh" --list 2>&1)
status=$?
assert_success "$status" "template list command succeeds"
assert_json_field "$output" ".status" "success"
assert_json_field "$output" ".mode" "list"
assert_json_number_gte "$output" ".templates | length" "10"
assert_json_field "$output" '.templates | index("feature/overview.md.tpl") != null' "true"
assert_json_field "$output" '.templates | index("project/ARCHITECTURE.md.tpl") != null' "true"
teardown_test_dir

it "reports template metadata drift and override hygiene issues"
setup_test_dir
init_git_repo
bash "$REPO_ROOT/scripts/init-harness.sh" --project-name sample-app >/dev/null 2>&1
bash "$REPO_ROOT/scripts/new-feature-spec.sh" --id FEAT-010 --title "Order Query" --owner alice --change-types api >/dev/null 2>&1

cat > docs/project/ARCHITECTURE.md <<'EOF'
---
id: project-architecture
title: 项目架构
type: project-architecture
status: active
owner: team
last_updated: 2026-04-07
template_version: 1.0.0
template_profile: java-backend-service
template_language: zh-CN
---

# 项目架构

## 系统上下文

订单服务负责订单创建与状态流转。

## 分层与包结构

controller / application / domain / infrastructure 四层分离。

## 事务边界与一致性

下单事务仅覆盖订单落库，消息通过 outbox 异步发送。
EOF

cat > docs/features/FEAT-010-order-query/overview.md <<'EOF'
---
id: FEAT-010
title: Order Query
type: feature-overview
status: draft
owner: alice
change_types: "api"
last_updated: 2026-04-07
template_version: 1.1.0
template_profile: generic
---

# 功能概览

## 业务背景与目标

补充订单查询能力。

## 范围

- 支持按订单号查询。

## 验收标准

- [ ] 支持订单查询接口。
EOF

bash "$REPO_ROOT/scripts/prepare-template-overrides.sh" --template feature/overview.md.tpl >/dev/null 2>&1
mkdir -p .harness/templates/feature
cat > .harness/templates/feature/status.md.tpl <<'EOF'
# 自定义状态模板
EOF
cat > .harness/templates/feature/custom-extra.md.tpl <<'EOF'
# 自定义扩展模板
EOF

output=$(bash "$REPO_ROOT/scripts/check-template-drift.sh" --json 2>&1)
status=$?
assert_eq "1" "$status" "template drift command reports issues"
assert_json_field "$output" ".status" "drifted"
assert_json_number_gte "$output" ".docs.checked_count" "2"
assert_json_number_gte "$output" ".docs.drifted_count" "2"
assert_json_number_gte "$output" ".docs.missing_metadata_count" "1"
assert_json_number_gte "$output" ".overrides.redundant_count" "1"
assert_json_number_gte "$output" ".overrides.custom_count" "1"
assert_json_number_gte "$output" ".overrides.orphan_count" "1"
assert_json_field "$output" '.overrides.redundant_overrides | index(".harness/templates/feature/overview.md.tpl") != null' "true"
assert_json_field "$output" '.overrides.custom_overrides | index(".harness/templates/feature/status.md.tpl") != null' "true"
assert_json_field "$output" '.overrides.orphan_overrides | index(".harness/templates/feature/custom-extra.md.tpl") != null' "true"
teardown_test_dir

print_summary
