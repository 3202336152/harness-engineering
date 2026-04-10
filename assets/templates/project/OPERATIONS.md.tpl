---
id: project-operations
title: 项目运行与变更基线
type: project-operations
status: active
owner: {{OWNER}}
last_updated: {{DATE}}
template_version: {{TEMPLATE_VERSION}}
template_profile: {{TEMPLATE_PROFILE}}
template_language: {{TEMPLATE_LANGUAGE}}
---

# 项目运行与变更基线

## 运行模式与职责分工

- 明确开发、测试、值班、发布负责人和升级路径。
- 说明工作时间、值班节奏和重大故障处理链路。

## 环境与配置基线

- 列出本地、测试、预发、生产环境差异。
- 说明关键开关、密钥、字典、外部依赖的配置来源。

## 变更执行要求

- 记录高风险变更、灰度策略、审批要求和通知机制。
- 说明哪些变更必须附带回滚方案和验证证据。

## 发布与回滚协同

- 发布窗口、回滚窗口、观察窗口的默认要求。
- 失败时的止血动作、回退动作和信息同步要求。

## 例行治理任务

- 说明模板漂移检查、文档健康检查、架构边界校验的执行频率。
- 记录哪些自治脚本接到了 CI、定时任务或本地钩子。
