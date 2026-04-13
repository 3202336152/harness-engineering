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
assert_file_exists "harness/.harness/runtime/java-doc-scan.json"
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
assert_json_field "$(cat harness/.harness/runtime/java-doc-scan.json)" '.inventory.controllers | map(.path) | index("src/main/java/com/example/order/interfaces/http/OrderController.java") != null' "true"
teardown_test_dir

it "scans Java sources and configs across multiple modules"
setup_test_dir
init_git_repo
mkdir -p module-api/src/main/java/com/example/api/interfaces/http
mkdir -p module-service/src/main/java/com/example/service/application
mkdir -p module-service/src/main/resources/config
cat > pom.xml <<'EOF'
<project xmlns="http://maven.apache.org/POM/4.0.0">
  <modelVersion>4.0.0</modelVersion>
  <groupId>com.example</groupId>
  <artifactId>platform-root</artifactId>
  <version>1.0.0</version>
</project>
EOF
cat > module-api/pom.xml <<'EOF'
<project xmlns="http://maven.apache.org/POM/4.0.0">
  <modelVersion>4.0.0</modelVersion>
  <artifactId>module-api</artifactId>
</project>
EOF
cat > module-service/pom.xml <<'EOF'
<project xmlns="http://maven.apache.org/POM/4.0.0">
  <modelVersion>4.0.0</modelVersion>
  <artifactId>module-service</artifactId>
</project>
EOF
cat > module-api/src/main/java/com/example/api/interfaces/http/BillingController.java <<'EOF'
package com.example.api.interfaces.http;

import org.springframework.web.bind.annotation.RestController;

@RestController
public class BillingController {}
EOF
cat > module-service/src/main/java/com/example/service/application/BillingApplicationService.java <<'EOF'
package com.example.service.application;

public class BillingApplicationService {}
EOF
cat > module-service/src/main/resources/bootstrap.yml <<'EOF'
spring:
  application:
    name: billing-service
EOF
cat > module-service/src/main/resources/config/application-prod.yml <<'EOF'
feature:
  billing: true
EOF
output=$(bash "$REPO_ROOT/scripts/scan-java-project.sh" --json 2>&1)
status=$?
assert_success "$status" "java scan succeeds on multi-module project"
assert_json_field "$output" '.inventory.module_paths | index("module-api") != null' "true"
assert_json_field "$output" '.inventory.module_paths | index("module-service") != null' "true"
assert_json_field "$output" '.inventory.controllers | map(.name) | index("BillingController") != null' "true"
assert_json_field "$output" '.inventory.application_services | map(.name) | index("BillingApplicationService") != null' "true"
assert_json_field "$output" '.inventory.config_files | index("module-service/src/main/resources/bootstrap.yml") != null' "true"
assert_json_field "$output" '.inventory.config_files | index("module-service/src/main/resources/config/application-prod.yml") != null' "true"
teardown_test_dir

it "infers deep business package roots and ignores annotation text inside comments or strings"
setup_test_dir
init_git_repo
mkdir -p src/main/java/cn/company/platform/biz/order/interfaces/http
mkdir -p src/main/java/cn/company/platform/biz/order/infrastructure/client
mkdir -p src/main/resources
cat > pom.xml <<'EOF'
<project xmlns="http://maven.apache.org/POM/4.0.0">
  <modelVersion>4.0.0</modelVersion>
  <groupId>cn.company.platform</groupId>
  <artifactId>order-platform</artifactId>
  <version>1.0.0</version>
</project>
EOF
cat > src/main/java/cn/company/platform/biz/order/interfaces/http/OrderController.java <<'EOF'
package cn.company.platform.biz.order.interfaces.http;

import org.springframework.web.bind.annotation.RestController;

@RestController
public class OrderController {}
EOF
cat > src/main/java/cn/company/platform/biz/order/infrastructure/client/PaymentGateway.java <<'EOF'
package cn.company.platform.biz.order.infrastructure.client;

import org.springframework.cloud.openfeign.FeignClient;

@FeignClient(name = "payment")
public interface PaymentGateway {}
EOF
cat > src/main/java/cn/company/platform/biz/order/interfaces/http/AnnotationSamples.java <<'EOF'
package cn.company.platform.biz.order.interfaces.http;

public class AnnotationSamples {
  // @RestController should not be treated as a real annotation
  private static final String CONTROLLER = "@RestController";
  private static final String CLIENT = "@FeignClient";

  /*
   * @KafkaListener(topics = "fake")
   * @Scheduled(fixedDelay = 1000)
   */
  public String sample() {
    return CONTROLLER + CLIENT;
  }
}
EOF
output=$(bash "$REPO_ROOT/scripts/scan-java-project.sh" --json 2>&1)
status=$?
assert_success "$status" "java scan handles deep package roots and annotation text safely"
assert_json_field "$output" '.inventory.package_roots | index("cn.company.platform.biz.order") != null' "true"
assert_json_field "$output" '.inventory.controllers | map(.name) | index("OrderController") != null' "true"
assert_json_field "$output" '.inventory.controllers | map(.name) | index("AnnotationSamples") == null' "true"
assert_json_field "$output" '.inventory.clients | map(.name) | index("PaymentGateway") != null' "true"
assert_json_field "$output" '.inventory.clients | map(.name) | index("AnnotationSamples") == null' "true"
assert_json_field "$output" '.inventory.listeners | map(.name) | index("AnnotationSamples") == null' "true"
assert_json_field "$output" '.inventory.jobs | map(.name) | index("AnnotationSamples") == null' "true"
teardown_test_dir

it "detects extended Spring component roles and bean factory methods"
setup_test_dir
init_git_repo
mkdir -p src/main/java/com/example/order/config src/main/java/com/example/order/support src/main/java/com/example/order/repository
cat > pom.xml <<'EOF'
<project xmlns="http://maven.apache.org/POM/4.0.0">
  <modelVersion>4.0.0</modelVersion>
  <groupId>com.example</groupId>
  <artifactId>order-app</artifactId>
  <version>1.0.0</version>
</project>
EOF
cat > src/main/java/com/example/order/repository/OrderRepository.java <<'EOF'
package com.example.order.repository;

import org.springframework.stereotype.Repository;

@Repository
public class OrderRepository {}
EOF
cat > src/main/java/com/example/order/support/OrderSupportComponent.java <<'EOF'
package com.example.order.support;

import org.springframework.stereotype.Component;

@Component
public class OrderSupportComponent {}
EOF
cat > src/main/java/com/example/order/config/OrderConfiguration.java <<'EOF'
package com.example.order.config;

import org.springframework.context.event.EventListener;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class OrderConfiguration {
  @Bean
  public OrderClock orderClock() {
    return new OrderClock();
  }

  @EventListener
  public void onOrderCreated(Object event) {}
}

class OrderClock {}
EOF
cat > src/main/java/com/example/order/config/OrderControllerAdvice.java <<'EOF'
package com.example.order.config;

import org.springframework.web.bind.annotation.ControllerAdvice;

@ControllerAdvice
public class OrderControllerAdvice {}
EOF
cat > src/main/java/com/example/order/config/OrderTraceAspect.java <<'EOF'
package com.example.order.config;

import org.aspectj.lang.annotation.Aspect;

@Aspect
public class OrderTraceAspect {}
EOF
cat > src/main/java/com/example/order/config/OrderProperties.java <<'EOF'
package com.example.order.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "order")
public class OrderProperties {}
EOF
output=$(bash "$REPO_ROOT/scripts/scan-java-project.sh" --json 2>&1)
status=$?
assert_success "$status" "java scan detects extended Spring component roles"
assert_json_field "$output" '.inventory.repositories | map(.name) | index("OrderRepository") != null' "true"
assert_json_field "$output" '.inventory.components | map(.name) | index("OrderSupportComponent") != null' "true"
assert_json_field "$output" '.inventory.configurations | map(.name) | index("OrderConfiguration") != null' "true"
assert_json_field "$output" '.inventory.controller_advices | map(.name) | index("OrderControllerAdvice") != null' "true"
assert_json_field "$output" '.inventory.aspects | map(.name) | index("OrderTraceAspect") != null' "true"
assert_json_field "$output" '.inventory.properties_bindings | map(.name) | index("OrderProperties") != null' "true"
assert_json_field "$output" '.inventory.event_listeners | map(.name) | index("OrderConfiguration") != null' "true"
assert_json_field "$output" '.inventory.bean_methods | map(.name) | index("orderClock") != null' "true"
teardown_test_dir

it "captures bean method names when @Bean is followed by additional annotations"
setup_test_dir
init_git_repo
mkdir -p src/main/java/com/example/order/config
cat > pom.xml <<'EOF'
<project xmlns="http://maven.apache.org/POM/4.0.0">
  <modelVersion>4.0.0</modelVersion>
  <groupId>com.example</groupId>
  <artifactId>order-app</artifactId>
  <version>1.0.0</version>
</project>
EOF
cat > src/main/java/com/example/order/config/OrderConfiguration.java <<'EOF'
package com.example.order.config;

import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class OrderConfiguration {
  @Bean
  @Qualifier("orderClock")
  public OrderClock orderClock() {
    return new OrderClock();
  }
}

class OrderClock {}
EOF
output=$(bash "$REPO_ROOT/scripts/scan-java-project.sh" --json 2>&1)
status=$?
assert_success "$status" "java scan keeps the factory method name when bean methods have extra annotations"
assert_json_field "$output" '.inventory.bean_methods | map(.name) | index("orderClock") != null' "true"
assert_json_field "$output" '.inventory.bean_methods | map(.name) | index("Qualifier") == null' "true"
teardown_test_dir

print_summary
