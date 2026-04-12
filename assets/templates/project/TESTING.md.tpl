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

建议至少覆盖复杂 Java 项目常见层次：

| 测试层级 | 目标 | 典型对象 | 建议工具/方式 | 合并前要求 |
|----------|------|----------|---------------|------------|
| 单元测试 | 规则正确 | util/domain/service/strategy | JUnit/Mockito | 核心规则必备 |
| Slice 测试 | 入口与协议正确 | controller/json/validation | MockMvc/WebTestClient | 关键接口建议覆盖 |
| 集成测试 | 组件协作 | repository/client/application | SpringBootTest/Testcontainers | 关键主链必备 |
| 消息/任务测试 | 异步正确 | listener/job/consumer | 本地 broker/桩/可控调度 | 关键异步流程必备 |
| 回归测试 | 复杂链路稳定 | 编排 + 表 + MQ + 缓存 | 命令化执行 | 发布前必须可执行 |
| 人工验收 | 联调与体验 | 业务流程 | 清单化执行 | 按需补充 |

## 测试数据与环境准备

- 测试库、测试账号、基础数据、Mock 服务如何准备
- 是否允许连共享测试环境，是否需要脱敏数据
- 定时任务、消息消费、异步线程如何在测试中控制
- 是否使用 Testcontainers、内存替身、Docker Compose 或共享联调环境

## 关键链路测试设计

建议对每条复杂主链至少写清楚：

1. 正常路径要覆盖哪些输入、输出和表变化。
2. 并发、重复请求、幂等重试、消息重复消费如何验证。
3. 外部依赖超时、失败、部分成功如何验证。
4. 事务提交、回滚、`afterCommit`、补偿任务如何验证。
5. 缓存删除、消息投递、审计日志和指标是否有观测点。

## 数据库、消息与异步任务验证

- DDL、索引、回填脚本、数据兼容性如何验证
- 消息发送、消费、重试、死信、幂等如何验证
- 定时任务、补偿任务、批处理作业如何验证

## 回归命令与观察点

建议固定一组最小回归命令，并记录：

- 对应测试类或测试套件
- 关键 SQL 校验
- 关键日志检索条件
- 关键指标、Topic 积压、死信、重试表观察点

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
