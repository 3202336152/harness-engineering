---
id: project-core-beliefs
title: 核心信念
type: project-core-beliefs
status: active
owner: {{OWNER}}
last_updated: {{DATE}}
template_version: {{TEMPLATE_VERSION}}
template_profile: {{TEMPLATE_PROFILE}}
template_language: {{TEMPLATE_LANGUAGE}}
---

# 核心信念

这份文档记录不应轻易改变的重要设计决策。每一条都应该说明理由、适用边界，以及什么情况下允许例外。

## 架构原则

- 记录长期稳定的分层边界和模块职责，以及哪些约束必须通过代码或 CI 机械化执行。
- 示例：domain 层不允许依赖 infrastructure 包，由 `lint-architecture.sh` 在 CI 中强制检查。
- 示例：ApplicationService 是默认事务边界，Controller/Listener/Job 只负责入口协议处理和调度。

## 业务边界与领域模型

- 记录哪些业务能力必须由本系统负责，哪些能力必须交给外部系统或上游/下游域处理。
- 记录哪些领域对象、状态机、一致性规则不能被轻易破坏。
- 示例：订单状态流转只能通过 `OrderDomainService` 驱动，禁止在 MQ Consumer 或 Mapper 中直接更新状态。

## 技术选型

- 记录主要技术栈选择及其原因，并说明各选型的适用边界。
- 对 Java 项目，建议明确 JDK、Spring Boot、持久化框架、消息组件、缓存方案和可替换边界。
- 示例：JDK 17 + Spring Boot 3.x + MyBatis，用于保证 SQL 可控与运行时一致性。

## 一致性与数据原则

- 记录事务边界、幂等策略、补偿原则、缓存一致性原则，以及哪些数据必须强一致、哪些允许最终一致。
- 示例：支付结果落库与事件发布采用本地消息表，缓存统一使用 Cache-Aside，禁止“先删缓存再写库”。
- 示例：幂等键统一使用业务唯一号，去重记录保留 24 小时。

## 接口与兼容性原则

- 记录对外接口、消息、数据库变更的兼容性底线。
- 记录字段废弃、版本升级、灰度发布时必须遵守的规则。
- 示例：HTTP 接口新增字段必须向后兼容，数据库列变更必须经历“新增列 -> 双写 -> 迁移 -> 下线旧列”。

## 质量标准

- 记录不可妥协的工程标准，例如测试门禁、评审红线、日志审计要求、性能基线和安全底线。
- 示例：核心 domain 规则必须有单元测试覆盖，生产日志不得输出完整密码、token、身份证号或银行卡号。
