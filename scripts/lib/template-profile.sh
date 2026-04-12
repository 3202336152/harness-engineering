#!/bin/bash

: "${TEMPLATE_VERSION_DEFAULT:=1.1.0}"
: "${TEMPLATE_LANGUAGE_DEFAULT:=zh-CN}"
: "${TEMPLATE_PACK_NAME_DEFAULT:=harness-engineering-default}"

default_template_profile_for_stack() {
  local stack="${1:-unknown}"
  case "$stack" in
    java-maven|java-gradle)
      printf 'java-backend-service'
      ;;
    python)
      printf 'python-service'
      ;;
    go)
      printf 'go-service'
      ;;
    rust)
      printf 'rust-service'
      ;;
    node)
      printf 'node-service'
      ;;
    *)
      printf 'generic'
      ;;
  esac
}

describe_template_profile() {
  local profile="${1:-generic}"
  case "$profile" in
    java-backend-service)
      printf '面向典型 Java 后端服务，重点关注模块职责、主链时序、接口契约、事务边界、缓存与消息一致性、外部集成、测试回归和灰度发布。'
      ;;
    java-batch-job)
      printf '面向批处理或定时任务型 Java 项目，重点关注批量窗口、任务幂等、补偿回查、数据迁移、对账验证和失败重跑。'
      ;;
    java-adapter)
      printf '面向集成适配型 Java 项目，重点关注协议转换、防腐层、重试降级、审计追踪、联调样例与上下游兼容。'
      ;;
    node-service)
      printf '面向 Node 服务项目，重点关注接口、异步任务、依赖治理和运行时可观测性。'
      ;;
    python-service)
      printf '面向 Python 服务项目，重点关注数据处理、任务调度、依赖隔离和运行稳定性。'
      ;;
    go-service)
      printf '面向 Go 服务项目，重点关注并发模型、接口稳定性、部署简洁性和资源效率。'
      ;;
    rust-service)
      printf '面向 Rust 服务项目，重点关注内存安全、性能边界、异步运行时和错误处理约定。'
      ;;
    *)
      printf '通用工程模板画像，适合在未明确技术场景前先建立基础 spec 结构，再按项目实际继续收敛。'
      ;;
  esac
}
