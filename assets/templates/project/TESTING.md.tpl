---
id: project-testing
title: 项目测试策略
type: project-testing
status: active
owner: {{OWNER}}
last_updated: {{DATE}}
template_version: {{TEMPLATE_VERSION}}
template_profile: {{TEMPLATE_PROFILE}}
template_language: {{TEMPLATE_LANGUAGE}}
---

# 项目测试策略

## 测试目标

明确项目希望通过自动化和人工验证守住哪些风险：功能正确性、接口兼容性、事务一致性、权限安全、性能稳定性等。

## 当前模板画像

- 模板版本：`{{TEMPLATE_VERSION}}`
- 模板画像：`{{TEMPLATE_PROFILE}}`
- 画像说明：{{PROFILE_DESCRIPTION}}

## 测试命令

```bash
{{TEST_COMMAND}}
```

## 测试分层矩阵

建议至少覆盖：

| 测试层级 | 目标 | 典型对象 | 建议工具/方式 | 合并前要求 |
|----------|------|----------|---------------|------------|
| 单元测试 | 规则正确 | util/domain/service | JUnit/Mockito | 核心逻辑必备 |
| 集成测试 | 组件协作 | repository/client/application | SpringBootTest/Testcontainers | 关键链路必备 |
| 接口测试 | 契约稳定 | controller/rpc | MockMvc/RestAssured | 对外接口建议覆盖 |
| 消息/任务测试 | 异步正确 | listener/job/consumer | 本地 broker/桩 | 关键异步流程必备 |
| 人工验收 | 体验与回归 | 业务流程 | 清单化执行 | 发布前按需执行 |

## 测试数据与环境准备

- 测试库、测试账号、基础数据、Mock 服务如何准备
- 是否允许连共享测试环境，是否需要脱敏数据
- 定时任务、消息消费、异步线程如何在测试中控制

## 数据库、消息与异步任务验证

- DDL、索引、回填脚本、数据兼容性如何验证
- 消息发送、消费、重试、死信、幂等如何验证
- 定时任务、补偿任务、批处理作业如何验证

## 最低验证要求

- 明确合并前必须通过的自动化检查。
- 记录接口、集成和端到端测试预期。
- 如果启用了文档影响门禁，明确 `check-doc-impact` 的触发范围和失败处理方式。
- 尽量保持测试输出可被机器解析。

## 发布与回归门禁

- 哪些能力必须在发布前全量回归
- 哪些风险项需要灰度观察后再放量
- 失败时由谁确认回滚与止血

## 验证证据要求

- PR 需要附哪些测试结果、日志、截图、SQL、调用记录
- 缺少自动化时，人工验证记录至少包含哪些信息
