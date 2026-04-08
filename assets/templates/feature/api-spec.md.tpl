---
id: {{FEATURE_ID}}
title: {{FEATURE_TITLE}}
type: feature-api-spec
status: draft
owner: {{OWNER}}
change_types: "{{CHANGE_TYPES}}"
last_updated: {{DATE}}
template_version: {{TEMPLATE_VERSION}}
template_profile: {{TEMPLATE_PROFILE}}
template_language: {{TEMPLATE_LANGUAGE}}
---

# 接口规格

## 接口范围

描述新增或变更的 API 接口面。

## 接口清单

| 接口 | 协议 | 调用方 | 说明 | 是否新增/变更 |
|------|------|--------|------|---------------|
| 例如：查询用户 | HTTP GET | 前端/内部服务 | 查询用户详情 | 新增 |

## 请求设计

- 路径、方法、RPC 方法名或消息主题
- 请求字段、必填校验、枚举取值、分页排序规则
- 幂等键、签名、鉴权上下文、租户/操作人透传方式

## 响应与错误码

- 成功响应结构
- 业务错误码、系统错误码、可重试错误
- 空值、兼容字段、部分成功场景的表达方式

## 校验、幂等与安全

- 参数校验和越权校验放在哪一层
- 是否需要防重、防刷、频控、审计
- 哪些字段不能落日志或必须脱敏

## 示例与兼容性

- 补充典型请求/响应示例
- 说明是否影响旧客户端、旧调用方、旧消息消费者

## 请求与响应格式

记录请求字段、响应字段和错误行为。
