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

## 模块与分层影响

说明受影响的模块、领域、分层和包路径，例如：

- `controller / rpc / listener / job`
- `application service`
- `domain service / aggregate / rule`
- `repository / mapper / client / cache`

## 核心设计方案

解释拟采用的实现方式以及核心权衡。

## 数据流与时序

建议说明：

- 请求/消息如何进入系统
- 核心业务步骤的执行顺序
- 数据落库、缓存更新、消息发送、外部调用的先后关系

## 事务、一致性与幂等

- 事务边界放在哪一层
- 是否涉及分布式事务、补偿、重试、幂等键、去重表
- 外部依赖失败时的处理方式

## 兼容性与回滚考虑

- 对旧接口、旧数据、旧消息、旧任务的兼容策略
- 如何关闭功能、回滚逻辑、回滚数据、恢复旧行为

## 风险与待确认问题

列出主要技术风险和交付风险。
