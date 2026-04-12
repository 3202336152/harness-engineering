---
id: {{FEATURE_ID}}
title: {{FEATURE_TITLE}}
type: feature-rollout
status: draft
owner: {{OWNER}}
change_types: "{{CHANGE_TYPES}}"
last_updated: {{DATE}}
template_version: {{TEMPLATE_VERSION}}
template_profile: {{TEMPLATE_PROFILE}}
template_language: {{TEMPLATE_LANGUAGE}}
---

# 发布与回滚方案

## 发布目标与策略

说明本次发布是灰度、全量、分批、按租户、按开关还是按环境推进。

## 发布前检查

- 配置、开关、字典、库表、索引、消息主题是否就绪
- 监控、告警、仪表盘、日志检索条件是否就绪
- 回滚资源、负责人、通知群、值班安排是否明确

## 发布计划

说明发布顺序、开关策略和观测方案。

## 发布步骤

按时间顺序列出执行步骤、负责人和检查点。

## 发布后观测指标

- 成功率、耗时、错误码、消息堆积、任务失败数
- 达到什么条件继续放量，达到什么条件暂停或回滚

## 回滚方案

说明如何安全关闭或回退该功能。

## 回滚触发条件

- 功能错误
- 性能劣化
- 数据异常
- 上下游兼容性问题

## 排障入口

- 出现问题后优先查看哪些日志、表、缓存、Topic、任务记录
- 是否存在手工补发、重试、补偿、回放入口，以及使用边界
