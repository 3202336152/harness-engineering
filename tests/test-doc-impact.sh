#!/bin/bash

set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# shellcheck source=tests/test-helpers.sh
. "$REPO_ROOT/tests/test-helpers.sh"

describe "check-doc-impact.sh"

it "fails when staged Java API changes do not include matching spec updates"
setup_test_dir
init_git_repo
cat > pom.xml <<'EOF'
<project xmlns="http://maven.apache.org/POM/4.0.0">
  <modelVersion>4.0.0</modelVersion>
  <groupId>com.example</groupId>
  <artifactId>sample-app</artifactId>
  <version>1.0.0</version>
</project>
EOF
bash "$REPO_ROOT/scripts/init-harness.sh" --project-name sample-app >/dev/null 2>&1
mkdir -p src/main/java/com/example/order/controller
cat > src/main/java/com/example/order/controller/OrderController.java <<'EOF'
package com.example.order.controller;

public class OrderController {}
EOF
git add src/main/java/com/example/order/controller/OrderController.java
output=$(bash "$REPO_ROOT/scripts/check-doc-impact.sh" --json --staged 2>&1)
status=$?
assert_eq "1" "$status" "doc impact gate fails when API docs are missing"
assert_json_field "$output" ".status" "invalid"
assert_json_number_gte "$output" ".changed_files_count" "1"
assert_json_number_gte "$output" ".triggered_rules_count" "1"
assert_json_number_gte "$output" ".violation_count" "1"
assert_json_field "$output" '.violations[0].rule_id' "java-api-surface"
teardown_test_dir

it "passes when staged Java API changes include matching feature api spec updates"
setup_test_dir
init_git_repo
cat > pom.xml <<'EOF'
<project xmlns="http://maven.apache.org/POM/4.0.0">
  <modelVersion>4.0.0</modelVersion>
  <groupId>com.example</groupId>
  <artifactId>sample-app</artifactId>
  <version>1.0.0</version>
</project>
EOF
bash "$REPO_ROOT/scripts/init-harness.sh" --project-name sample-app >/dev/null 2>&1
mkdir -p src/main/java/com/example/order/controller docs/features/FEAT-001-order-query
cat > src/main/java/com/example/order/controller/OrderController.java <<'EOF'
package com.example.order.controller;

public class OrderController {}
EOF
cat > docs/features/FEAT-001-order-query/api-spec.md <<'EOF'
---
id: FEAT-001
title: 订单查询
type: feature-api-spec
status: draft
owner: alice
last_updated: 2026-04-08
template_version: 1.1.0
template_profile: java-backend-service
template_language: zh-CN
---

# 接口规格

## 接口清单

- GET /orders/{id}
EOF
git add src/main/java/com/example/order/controller/OrderController.java docs/features/FEAT-001-order-query/api-spec.md
output=$(bash "$REPO_ROOT/scripts/check-doc-impact.sh" --json --staged 2>&1)
status=$?
assert_success "$status" "doc impact gate passes when matching API docs are staged"
assert_json_field "$output" ".status" "passed"
assert_json_number_gte "$output" ".satisfied_rules_count" "1"
assert_json_field "$output" '.satisfied_rules[0].rule_id' "java-api-surface"
teardown_test_dir

print_summary
