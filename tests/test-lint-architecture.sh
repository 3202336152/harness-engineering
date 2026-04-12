#!/bin/bash

set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# shellcheck source=tests/test-helpers.sh
. "$REPO_ROOT/tests/test-helpers.sh"

describe "lint-architecture.sh"

it "reports a violation when a lower layer imports a higher layer"
setup_test_dir
init_git_repo
mkdir -p .harness src/user/types src/user/service
cat > .harness/architecture.json <<'EOF'
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
mkdir -p .harness src/user/types src/user/service
cat > .harness/architecture.json <<'EOF'
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
mkdir -p .harness src/main/java/order/application src/main/java/order/infrastructure
cat > .harness/architecture.json <<'EOF'
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

print_summary
