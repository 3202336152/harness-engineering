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

it "suggests follow-up docs and writes an action plan for violations"
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
output=$(bash "$REPO_ROOT/scripts/check-doc-impact.sh" --json --staged --suggest-actions --write-action-plan harness/.harness/doc-actions.json 2>&1)
status=$?
assert_eq "1" "$status" "doc impact gate still fails when suggestions are enabled"
assert_file_exists "harness/.harness/doc-actions.json"
assert_json_number_gte "$output" ".suggested_action_count" "1"
assert_json_field "$output" '.suggested_actions[0].target_paths | index("harness/docs/project/接口规范.md") != null' "true"
assert_json_field "$(cat harness/.harness/doc-actions.json)" ".status" "planned"
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
mkdir -p src/main/java/com/example/order/controller harness/docs/features/FEAT-001-order-query
cat > src/main/java/com/example/order/controller/OrderController.java <<'EOF'
package com.example.order.controller;

public class OrderController {}
EOF
cat > harness/docs/features/FEAT-001-order-query/接口设计.md <<'EOF'
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
git add src/main/java/com/example/order/controller/OrderController.java harness/docs/features/FEAT-001-order-query/接口设计.md
output=$(bash "$REPO_ROOT/scripts/check-doc-impact.sh" --json --staged 2>&1)
status=$?
assert_success "$status" "doc impact gate passes when matching API docs are staged"
assert_json_field "$output" ".status" "passed"
assert_json_number_gte "$output" ".satisfied_rules_count" "1"
assert_json_field "$output" '.satisfied_rules[0].rule_id' "java-api-surface"
teardown_test_dir

it "passes when there are no changed files"
setup_test_dir
init_git_repo
bash "$REPO_ROOT/scripts/init-harness.sh" --project-name sample-app >/dev/null 2>&1
output=$(bash "$REPO_ROOT/scripts/check-doc-impact.sh" --json 2>&1)
status=$?
assert_success "$status" "doc impact gate passes when no files changed"
assert_json_field "$output" ".status" "passed"
assert_json_field "$output" ".changed_files_count" "0"
assert_json_field "$output" ".violation_count" "0"
teardown_test_dir

it "defaults to staged changes when staged files exist"
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
git add -A >/dev/null 2>&1
git commit -m "baseline" --quiet >/dev/null 2>&1
mkdir -p src/main/java/com/example/order/controller
cat > src/main/java/com/example/order/controller/OrderController.java <<'EOF'
package com.example.order.controller;

public class OrderController {}
EOF
printf '\n- GET /orders/{id}\n' >> "harness/docs/project/接口规范.md"
git add src/main/java/com/example/order/controller/OrderController.java >/dev/null 2>&1
output=$(bash "$REPO_ROOT/scripts/check-doc-impact.sh" --json 2>&1)
status=$?
assert_eq "1" "$status" "default mode inspects staged diff when index is non-empty"
assert_json_field "$output" ".status" "invalid"
assert_json_field "$output" ".diff_source" "staged"
assert_json_field "$output" ".changed_files_count" "1"
teardown_test_dir

it "falls back to working tree changes when nothing is staged"
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
git add -A >/dev/null 2>&1
git commit -m "baseline" --quiet >/dev/null 2>&1
printf '\npublic String status() { return "ok"; }\n' >> src/main/java/com/example/order/controller/OrderController.java
output=$(bash "$REPO_ROOT/scripts/check-doc-impact.sh" --json 2>&1)
status=$?
assert_eq "1" "$status" "default mode falls back to working tree when index is empty"
assert_json_field "$output" ".status" "invalid"
assert_json_field "$output" ".diff_source" "working_tree"
assert_json_field "$output" ".changed_files_count" "1"
teardown_test_dir

print_summary
