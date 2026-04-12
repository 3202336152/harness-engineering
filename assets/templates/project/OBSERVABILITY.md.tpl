---
id: project-observability
title: 项目可观测性基线
type: project-observability
status: active
owner: {{OWNER}}
last_updated: {{DATE}}
doc_state: scaffold
template_version: {{TEMPLATE_VERSION}}
template_profile: {{TEMPLATE_PROFILE}}
template_language: {{TEMPLATE_LANGUAGE}}
---

# 项目可观测性基线

## 关键日志字段

- 至少统一 `traceId`、`requestId`、`operatorId`、`tenantId`、`featureId` 的输出口径。
- 明确敏感字段脱敏规则和审计日志落点。
- 明确复杂链路的核心业务键，例如 `orderId`、`taskId`、`messageKey`、`bizId` 等。

## 核心指标

- 成功率、耗时、错误码、任务失败数、消息堆积、数据库异常数。
- 说明哪些指标用于放量判断，哪些指标用于回滚触发。

## Trace、事件与排障链路

- 哪些入口默认要打 trace/span，哪些任务、消息消费必须串上同一业务键
- 哪些事件记录、重试记录、死信记录、补偿记录是排障第一入口
- 是否需要记录 `afterCommit` 发送结果、回调结果、定时任务扫描范围

## 仪表盘与检索入口

- 列出排查常用 dashboard、日志检索语句、链路追踪入口。
- 说明日常巡检与发布观察时必须关注的图表。

## 告警分级与处理

- 明确 P1/P2/P3 告警的触发条件、响应时限和处理责任人。
- 说明自治脚本失败时如何通知和升级。

## 验证证据沉淀

- 规定发布后需要保存哪些日志、截图、指标快照和回归记录。
- 说明这些证据保存在哪、保存多久、谁负责复盘。
