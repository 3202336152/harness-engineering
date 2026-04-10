---
id: project-api-spec
title: 项目接口规范
type: project-api-spec
status: active
owner: {{OWNER}}
last_updated: {{DATE}}
template_version: {{TEMPLATE_VERSION}}
template_profile: {{TEMPLATE_PROFILE}}
template_language: {{TEMPLATE_LANGUAGE}}
---

# 项目接口规范

## 文档定位

本文覆盖项目对外提供或消费的接口规范，适用于 REST、RPC、消息事件、回调接口等。

## 协议与接口类型

请按项目实际补充：

- HTTP / REST
- RPC（Dubbo、gRPC、内部协议）
- MQ Event / Command / Notification
- 定时任务或批处理的输入输出契约
- 第三方回调或 webhook

## 接口清单

建议使用表格维护：

| 接口名 | 协议 | 提供方/消费方 | 主要用途 | 链接到详细文档 |
|--------|------|---------------|----------|----------------|
| 例如：查询用户 | HTTP GET | 提供方 | 用户详情查询 | `docs/features/.../接口设计.md` |

## 通用上下文约定

- 认证身份、租户、操作人、traceId、requestId 的传递规则
- 时区、语言、币种、分页参数的统一约定
- 幂等键、签名、版本号、客户端标识的使用方式

## 请求参数设计规范

- 优先使用明确字段而不是 `Map<String, Object>`
- 使用 Bean Validation 或同类机制表达参数约束
- 对枚举、时间、金额、分页参数采用统一格式
- 批量接口要说明数量上限、顺序语义和部分失败策略

## 响应体与错误码规范

- 统一成功响应结构、业务码、系统码
- 对可重试错误、业务拒绝、权限不足、资源不存在分别给出约定
- 明确空值、空数组、默认值、兼容字段的处理原则

## 幂等性、分页与兼容性

- 新增、更新、消费类接口说明幂等方案
- 查询类接口说明排序字段、分页游标或页码规则
- 版本升级、字段新增、字段废弃、默认行为变更的兼容策略

## 安全、审计与可观测要求

- 哪些接口必须鉴权、鉴租户、验签或审计
- 哪些字段需要脱敏或禁止落日志
- 接口调用最少需要输出哪些日志、指标、trace 信息

## 共享 Schema 与示例来源

- 链接 OpenAPI / Protobuf / AsyncAPI / JSON Schema 的真实来源
- 链接 Mock、联调环境、示例请求与响应
