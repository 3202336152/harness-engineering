---
id: {{FEATURE_ID}}
title: {{FEATURE_TITLE}}
type: feature-design
status: draft
owner: {{OWNER}}
change_types: "{{CHANGE_TYPES}}"
last_updated: {{DATE}}
template_version: {{TEMPLATE_VERSION}}
template_profile: {{TEMPLATE_PROFILE}}
template_language: {{TEMPLATE_LANGUAGE}}
---

# 设计说明

## 变更摘要

用 3-5 行说明本次功能会改动什么，不改动什么，为什么选这个方案。

## 当前代码挂点与拟改动类

建议至少列出当前主入口和拟改动位置：

| 层级/模块 | 当前入口或类 | 本次改动方式 | 是否新增 | 备注 |
|-----------|--------------|--------------|----------|------|
| 接口层 | `OrderController` | 新增参数/接口 | 否 | 入站 HTTP |
| 编排层 | `OrderAppService` | 调整主流程 | 否 | 事务入口 |
| 数据层 | `OrderMapper.xml` | 新增 SQL | 否 | 需评估索引 |

## 模块与分层影响

说明受影响的模块、领域、分层和包路径，例如：

- `controller / rpc / listener / job`
- `application service`
- `domain service / aggregate / rule`
- `repository / mapper / client / cache`

## 核心设计方案

解释拟采用的实现方式以及核心权衡。

## 主链路时序与处理步骤

建议按实际执行顺序说明：

- 请求/消息如何进入系统
- 核心业务步骤的执行顺序
- 数据落库、缓存更新、消息发送、外部调用的先后关系
- 成功、失败、跳过、重试分别怎么走

## 关键数据对象、表、缓存与消息

建议列出本次功能真正依赖的对象：

| 类型 | 名称 | 用途 | 写入/消费方 | 风险点 |
|------|------|------|-------------|--------|
| DTO | `CreateOrderCommand` | 编排入参 | application | 字段兼容 |
| 表 | `t_order` | 状态持久化 | mapper | 唯一键 |
| 缓存 | `order:detail:{id}` | 查询缓存 | application | 双删一致性 |
| Topic | `order-created` | 出站事件 | producer | 消费幂等 |

## 事务、一致性与幂等

- 事务边界放在哪一层
- 是否涉及分布式事务、补偿、重试、幂等键、去重表
- 外部依赖失败时的处理方式

## 失败处理、补偿与回滚考虑

- 对旧接口、旧数据、旧消息、旧任务的兼容策略
- 如何关闭功能、回滚逻辑、回滚数据、恢复旧行为

## 实施顺序与最小改动集

建议明确实施顺序，而不是把所有内容一起改：

1. 先改哪些入口和校验。
2. 再改哪些核心服务和规则。
3. 再补哪些 SQL、缓存、消息或任务。
4. 最后补哪些测试、文档和发布项。

## 关键回归点

- 哪些测试类必须更新
- 哪些 SQL、日志、指标需要验证
- 哪些联调场景必须重新走通

## 风险与待确认问题

列出主要技术风险和交付风险。
