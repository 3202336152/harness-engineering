---
id: project-architecture
title: 项目架构
type: project-architecture
status: active
owner: {{OWNER}}
last_updated: {{DATE}}
template_version: {{TEMPLATE_VERSION}}
template_profile: {{TEMPLATE_PROFILE}}
template_language: {{TEMPLATE_LANGUAGE}}
---

# 项目架构

## 文档定位

本文是项目级共享架构基线，面向开发、评审、测试、运维和 AI 代理。
对于 Java 项目，建议优先明确模块边界、分层职责、事务边界、一致性策略和外部集成方式。

## 当前模板画像

- 模板版本：`{{TEMPLATE_VERSION}}`
- 模板画像：`{{TEMPLATE_PROFILE}}`
- 画像说明：{{PROFILE_DESCRIPTION}}

## 系统上下文

请补充以下信息：

- 仓库负责的核心业务能力和边界
- 核心参与方：用户、运营、内部系统、第三方系统
- 主要入口：HTTP API、RPC、MQ、定时任务、批处理、管理后台
- 关键外部依赖：数据库、缓存、消息中间件、搜索、对象存储、外部服务

## 业务域与模块边界

建议用表格说明：

| 领域/模块 | 主要职责 | 对外暴露能力 | 不应承担的职责 |
|-----------|----------|--------------|----------------|
| 例如：user | 用户资料、身份状态 | 用户查询、用户更新 | 支付、订单编排 |

## 分层与包结构

推荐 Java 服务优先采用以下分层，单体、多模块、微服务都可参考：

```text
interfaces (controller/rpc/listener/job)
  -> application
  -> domain
  -> infrastructure
```

补充约定：

- `interfaces` 层负责协议转换、参数校验、鉴权上下文接入。
- `application` 层负责编排用例、事务边界、权限校验、幂等控制。
- `domain` 层负责核心业务规则、聚合、一致性约束。
- `infrastructure` 层负责数据库、缓存、MQ、第三方 SDK、RPC client 的技术实现。
- 公共组件进入 shared/common 前，先证明其跨模块复用价值。

## 分层模型

记录团队与代理都必须遵守的依赖流向。

```text
Types -> Config -> Repo -> Service -> Runtime -> UI
```

## 核心调用链路

建议至少覆盖以下链路：

1. 外部请求如何进入系统，以及在哪一层做参数校验和鉴权。
2. 核心业务逻辑由哪些 application service / domain service 承担。
3. 数据写入、事件发布、缓存更新、外部调用的先后顺序。
4. 异常、超时、降级、补偿分别在哪一层处理。

## 事务边界与一致性

请明确：

- 事务通常由哪一层开启，是否允许跨多个聚合或多个 repository。
- 本地事务、分布式事务、事件最终一致性各自的使用边界。
- 外部 RPC / HTTP 调用是否允许放在数据库事务中。
- 幂等、去重、重试、补偿、回查的统一策略。

## 数据访问与持久化约定

结合项目实际说明：

- 使用 MyBatis / JPA / MyBatis-Plus / jOOQ 等哪种持久化方案。
- `Entity / Aggregate / DO / PO / DTO / VO` 的职责边界。
- 是否允许跨领域直接查表，是否必须通过领域服务或防腐层访问。
- 分页、批量、索引、锁、读写分离、归档、软删的统一约定。

## 缓存、消息与异步任务

需要写清楚：

- Redis/本地缓存的使用场景、Key 规范、失效策略、双写风险。
- MQ Topic / Tag / Consumer Group 的归属和命名规则。
- 定时任务、批处理、异步线程池的入口、限流、重试、告警要求。
- 消息消费与任务执行的幂等策略。

## 外部集成与防腐层

列出外部系统接入规范：

- 统一通过 client / gateway / adapter 封装外部调用。
- 禁止业务代码散落第三方协议细节。
- 外部依赖的超时、重试、熔断、降级、审计要求。
- 如果存在老系统或异构协议，说明防腐层的放置位置和转换规则。

## 可观测性与运行保障

至少明确：

- 日志字段规范：`traceId`、`requestId`、`operatorId`、`tenantId` 等。
- 指标与告警：成功率、耗时、错误码、消息堆积、任务失败数。
- 链路追踪、审计日志、业务埋点的落点。
- 线上问题排查时依赖哪些 dashboard、日志、SQL、事件记录。

## 安全与合规边界

记录接口鉴权、数据脱敏、权限校验、操作审计、敏感配置管理的统一原则，
并链接到 `docs/project/安全规范.md` 的详细要求。

## 机械化约束

- 保持本文与 `.harness/architecture.json` 一致。
- 在 CI 中强制执行架构边界校验。
- 例外情况记录到 `docs/decisions/`。
- 重要模块重构时同步更新图示、调用链和边界约束。
