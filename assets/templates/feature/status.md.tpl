---
id: {{FEATURE_ID}}
title: {{FEATURE_TITLE}}
type: feature-status
status: draft
owner: {{OWNER}}
change_types: "{{CHANGE_TYPES}}"
last_updated: {{DATE}}
doc_state: scaffold
template_version: {{TEMPLATE_VERSION}}
template_profile: {{TEMPLATE_PROFILE}}
template_language: {{TEMPLATE_LANGUAGE}}
---

# 功能状态

## 当前状态

建议用表格维护：

| 字段 | 当前值 |
|------|--------|
| 状态 | Draft / In Review / Approved / Implementing / Complete |
| 负责人 | `{{OWNER}}` |
| 最近更新时间 | `{{DATE}}` |
| 当前里程碑 | 待补充 |

## 流程状态

- Draft
- In review
- Approved
- Implementing
- Complete

## 本轮实现与剩余项

建议拆成两部分：

- 本轮已经完成的功能、接口、SQL、测试、文档
- 当前仍未完成或后续阶段再补的内容

## 当前阶段检查项

- [ ] 需求已确认
- [ ] 设计已评审
- [ ] 接口/数据库变更已确认
- [ ] 测试方案已确认
- [ ] 发布与回滚方案已确认

## 阻塞与风险

- 在这里记录当前 blocker、负责人和预计解决时间。

## 关联信息

- 在这里关联执行计划、PR 和设计决策。
