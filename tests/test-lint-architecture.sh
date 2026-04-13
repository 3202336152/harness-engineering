#!/bin/bash

set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# shellcheck source=tests/test-helpers.sh
. "$REPO_ROOT/tests/test-helpers.sh"

describe "lint-architecture.sh"

it "reports a violation when a lower layer imports a higher layer"
setup_test_dir
init_git_repo
mkdir -p harness/.harness src/user/types src/user/service
cat > harness/.harness/architecture.json <<'EOF'
{
  "layers": ["types", "service"],
  "src_root": "src",
  "cross_domain_allowed_via": "providers"
}
EOF
cat > src/user/types/user-dto.ts <<'EOF'
import { userService } from "../service/user-service";
EOF
cat > src/user/service/user-service.ts <<'EOF'
export const userService = {};
EOF
output=$(bash "$REPO_ROOT/scripts/lint-architecture.sh" 2>&1)
status=$?
assert_eq "1" "$status" "lint exits non-zero on violation"
assert_json_field "$output" ".status" "violations"
assert_json_number_gte "$output" ".violations | length" "1"
teardown_test_dir

it "passes when imports respect layer order"
setup_test_dir
init_git_repo
mkdir -p harness/.harness src/user/types src/user/service
cat > harness/.harness/architecture.json <<'EOF'
{
  "layers": ["types", "service"],
  "src_root": "src",
  "cross_domain_allowed_via": "providers"
}
EOF
cat > src/user/types/user-dto.ts <<'EOF'
export interface UserDto {}
EOF
cat > src/user/service/user-service.ts <<'EOF'
import type { UserDto } from "../types/user-dto";
export const toDto = (value: UserDto) => value;
EOF
output=$(bash "$REPO_ROOT/scripts/lint-architecture.sh" 2>&1)
status=$?
assert_success "$status" "lint succeeds when boundaries are respected"
assert_json_field "$output" ".status" "passed"
teardown_test_dir

it "honors explicit forbidden dependency rules"
setup_test_dir
init_git_repo
mkdir -p harness/.harness src/main/java/order/application src/main/java/order/infrastructure
cat > harness/.harness/architecture.json <<'EOF'
{
  "layers": ["domain", "application", "infrastructure", "interfaces"],
  "src_root": "src/main/java",
  "cross_domain_allowed_via": "anti-corruption-layer",
  "forbidden_dependencies": ["application -> infrastructure"]
}
EOF
cat > src/main/java/order/application/OrderAppService.java <<'EOF'
import "../infrastructure/OrderRepositoryImpl";
EOF
cat > src/main/java/order/infrastructure/OrderRepositoryImpl.java <<'EOF'
public class OrderRepositoryImpl {}
EOF
output=$(bash "$REPO_ROOT/scripts/lint-architecture.sh" 2>&1)
status=$?
assert_eq "1" "$status" "lint exits non-zero on forbidden dependency"
assert_json_field "$output" ".status" "violations"
assert_json_field "$output" '.violations | map(select(.message | contains("Forbidden dependency"))) | length' "1"
teardown_test_dir

it "parses real Java imports and catches forbidden layer dependencies"
setup_test_dir
init_git_repo
mkdir -p harness/.harness src/main/java/com/example/order/application src/main/java/com/example/order/infrastructure
cat > harness/.harness/architecture.json <<'EOF'
{
  "layers": ["domain", "application", "infrastructure", "interfaces"],
  "src_root": "src/main/java",
  "cross_domain_allowed_via": "anti-corruption-layer",
  "forbidden_dependencies": ["application -> infrastructure"]
}
EOF
cat > src/main/java/com/example/order/application/OrderApplicationService.java <<'EOF'
package com.example.order.application;

import com.example.order.infrastructure.OrderRepositoryImpl;

public class OrderApplicationService {
  private final OrderRepositoryImpl repository = new OrderRepositoryImpl();
}
EOF
cat > src/main/java/com/example/order/infrastructure/OrderRepositoryImpl.java <<'EOF'
package com.example.order.infrastructure;

public class OrderRepositoryImpl {}
EOF
output=$(bash "$REPO_ROOT/scripts/lint-architecture.sh" 2>&1)
status=$?
assert_eq "1" "$status" "lint exits non-zero on real Java forbidden dependency"
assert_json_field "$output" ".status" "violations"
assert_json_field "$output" '.violations | map(select(.import == "com.example.order.infrastructure.OrderRepositoryImpl")) | length' "1"
assert_json_field "$output" '.violations | map(select(.layer == "application" and .target_layer == "infrastructure")) | length' "1"
teardown_test_dir

it "supports multiple source roots configured via src_roots"
setup_test_dir
init_git_repo
mkdir -p harness/.harness module-api/src/main/java/com/example/order/application module-infra/src/main/java/com/example/order/infrastructure
cat > harness/.harness/architecture.json <<'EOF'
{
  "layers": ["domain", "application", "infrastructure", "interfaces"],
  "src_roots": ["module-api/src/main/java", "module-infra/src/main/java"],
  "cross_domain_allowed_via": "anti-corruption-layer",
  "forbidden_dependencies": ["application -> infrastructure"]
}
EOF
cat > module-api/src/main/java/com/example/order/application/OrderApplicationService.java <<'EOF'
package com.example.order.application;

import com.example.order.infrastructure.OrderRepositoryImpl;

public class OrderApplicationService {
  private final OrderRepositoryImpl repository = new OrderRepositoryImpl();
}
EOF
cat > module-infra/src/main/java/com/example/order/infrastructure/OrderRepositoryImpl.java <<'EOF'
package com.example.order.infrastructure;

public class OrderRepositoryImpl {}
EOF
output=$(bash "$REPO_ROOT/scripts/lint-architecture.sh" 2>&1)
status=$?
assert_eq "1" "$status" "lint exits non-zero on multi-root forbidden dependency"
assert_json_field "$output" ".status" "violations"
assert_json_field "$output" '.violations | map(select(.file == "module-api/src/main/java/com/example/order/application/OrderApplicationService.java")) | length' "1"
assert_json_field "$output" '.violations | map(select(.target_layer == "infrastructure")) | length' "1"
teardown_test_dir

it "allows configured cross-layer type imports via glob patterns"
setup_test_dir
init_git_repo
mkdir -p harness/.harness src/main/java/com/example/order/application src/main/java/com/example/order/infrastructure/dto
cat > harness/.harness/architecture.json <<'EOF'
{
  "layers": ["domain", "application", "infrastructure", "interfaces"],
  "src_root": "src/main/java",
  "cross_domain_allowed_via": "anti-corruption-layer",
  "forbidden_dependencies": ["application -> infrastructure"],
  "allowed_cross_layer_types": ["*.dto.*"]
}
EOF
cat > src/main/java/com/example/order/application/OrderApplicationService.java <<'EOF'
package com.example.order.application;

import com.example.order.infrastructure.dto.OrderSummaryDto;

public class OrderApplicationService {
  private final OrderSummaryDto summary = new OrderSummaryDto();
}
EOF
cat > src/main/java/com/example/order/infrastructure/dto/OrderSummaryDto.java <<'EOF'
package com.example.order.infrastructure.dto;

public class OrderSummaryDto {}
EOF
output=$(bash "$REPO_ROOT/scripts/lint-architecture.sh" 2>&1)
status=$?
assert_success "$status" "lint allows configured cross-layer dto imports"
assert_json_field "$output" ".status" "passed"
teardown_test_dir

it "parses wildcard Java imports when checking forbidden dependencies"
setup_test_dir
init_git_repo
mkdir -p harness/.harness src/main/java/com/example/order/application src/main/java/com/example/order/infrastructure
cat > harness/.harness/architecture.json <<'EOF'
{
  "layers": ["domain", "application", "infrastructure", "interfaces"],
  "src_root": "src/main/java",
  "cross_domain_allowed_via": "anti-corruption-layer",
  "forbidden_dependencies": ["application -> infrastructure"]
}
EOF
cat > src/main/java/com/example/order/application/OrderApplicationService.java <<'EOF'
package com.example.order.application;

import com.example.order.infrastructure.*;

public class OrderApplicationService {}
EOF
cat > src/main/java/com/example/order/infrastructure/OrderRepositoryImpl.java <<'EOF'
package com.example.order.infrastructure;

public class OrderRepositoryImpl {}
EOF
output=$(bash "$REPO_ROOT/scripts/lint-architecture.sh" 2>&1)
status=$?
assert_eq "1" "$status" "lint exits non-zero on wildcard forbidden dependency"
assert_json_field "$output" ".status" "violations"
assert_json_field "$output" '.violations | map(select(.import == "com.example.order.infrastructure.*")) | length' "1"
teardown_test_dir

it "treats warning severities as non-blocking violations"
setup_test_dir
init_git_repo
mkdir -p harness/.harness src/user/types src/user/service
cat > harness/.harness/architecture.json <<'EOF'
{
  "layers": ["types", "service"],
  "src_root": "src",
  "cross_domain_allowed_via": "providers",
  "severity": {
    "layer_direction": "warning"
  }
}
EOF
cat > src/user/types/user-dto.ts <<'EOF'
import { userService } from "../service/user-service";
EOF
cat > src/user/service/user-service.ts <<'EOF'
export const userService = {};
EOF
output=$(bash "$REPO_ROOT/scripts/lint-architecture.sh" 2>&1)
status=$?
assert_success "$status" "lint succeeds when the violation severity is warning"
assert_json_field "$output" ".status" "warnings"
assert_json_field "$output" ".violations[0].rule" "layer_direction"
assert_json_field "$output" ".violations[0].severity" "warning"
teardown_test_dir

print_summary
