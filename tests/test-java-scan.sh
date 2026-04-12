#!/bin/bash

set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# shellcheck source=tests/test-helpers.sh
. "$REPO_ROOT/tests/test-helpers.sh"

describe "java scan"

it "scans a java project and writes the runtime inventory"
setup_test_dir
init_git_repo
mkdir -p src/main/java/com/example/order/interfaces/http
mkdir -p src/main/java/com/example/order/interfaces/mq
mkdir -p src/main/java/com/example/order/interfaces/job
mkdir -p src/main/java/com/example/order/infrastructure/client
mkdir -p src/main/java/com/example/order/application
mkdir -p src/main/java/com/example/order/domain/service
mkdir -p src/main/resources
cat > pom.xml <<'EOF'
<project xmlns="http://maven.apache.org/POM/4.0.0">
  <modelVersion>4.0.0</modelVersion>
  <groupId>com.example</groupId>
  <artifactId>order-app</artifactId>
  <version>1.0.0</version>
</project>
EOF
cat > src/main/java/com/example/order/OrderApplication.java <<'EOF'
package com.example.order;

import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class OrderApplication {
  public static void main(String[] args) {}
}
EOF
cat > src/main/java/com/example/order/interfaces/http/OrderController.java <<'EOF'
package com.example.order.interfaces.http;

import org.springframework.web.bind.annotation.RestController;

@RestController
public class OrderController {}
EOF
cat > src/main/java/com/example/order/interfaces/mq/OrderCreatedListener.java <<'EOF'
package com.example.order.interfaces.mq;

import org.springframework.kafka.annotation.KafkaListener;

public class OrderCreatedListener {
  @KafkaListener(topics = "order-created")
  public void onMessage(String body) {}
}
EOF
cat > src/main/java/com/example/order/interfaces/job/OrderRepairJob.java <<'EOF'
package com.example.order.interfaces.job;

import org.springframework.scheduling.annotation.Scheduled;

public class OrderRepairJob {
  @Scheduled(fixedDelay = 1000)
  public void run() {}
}
EOF
cat > src/main/java/com/example/order/infrastructure/client/PaymentClient.java <<'EOF'
package com.example.order.infrastructure.client;

import org.springframework.cloud.openfeign.FeignClient;

@FeignClient(name = "payment")
public interface PaymentClient {}
EOF
cat > src/main/java/com/example/order/application/OrderApplicationService.java <<'EOF'
package com.example.order.application;

public class OrderApplicationService {}
EOF
cat > src/main/java/com/example/order/domain/service/OrderDomainService.java <<'EOF'
package com.example.order.domain.service;

public class OrderDomainService {}
EOF
cat > src/main/resources/application.yml <<'EOF'
spring:
  application:
    name: order-app
EOF
output=$(bash "$REPO_ROOT/scripts/scan-java-project.sh" --json 2>&1)
status=$?
assert_success "$status" "java scan command succeeds"
assert_file_exists ".harness/runtime/java-doc-scan.json"
assert_json_field "$output" ".status" "success"
assert_json_field "$output" ".stack" "java-maven"
assert_json_field "$output" '.inventory.package_roots | index("com.example.order") != null' "true"
assert_json_field "$output" '.inventory.entrypoints | map(.name) | index("OrderApplication") != null' "true"
assert_json_field "$output" '.inventory.controllers | map(.name) | index("OrderController") != null' "true"
assert_json_field "$output" '.inventory.listeners | map(.name) | index("OrderCreatedListener") != null' "true"
assert_json_field "$output" '.inventory.jobs | map(.name) | index("OrderRepairJob") != null' "true"
assert_json_field "$output" '.inventory.clients | map(.name) | index("PaymentClient") != null' "true"
assert_json_field "$output" '.inventory.application_services | map(.name) | index("OrderApplicationService") != null' "true"
assert_json_field "$output" '.inventory.domain_services | map(.name) | index("OrderDomainService") != null' "true"
assert_json_field "$output" '.recommended_reads | index("pom.xml") != null' "true"
assert_json_field "$output" '.recommended_reads | map(select(. == "src/main/resources/application.yml")) | length' "1"
assert_json_field "$(cat .harness/runtime/java-doc-scan.json)" '.inventory.controllers | map(.path) | index("src/main/java/com/example/order/interfaces/http/OrderController.java") != null' "true"
teardown_test_dir

print_summary
