---
id: {{FEATURE_ID}}
title: {{FEATURE_TITLE}}
type: feature-db-spec
status: draft
owner: {{OWNER}}
change_types: "{{CHANGE_TYPES}}"
last_updated: {{DATE}}
template_version: {{TEMPLATE_VERSION}}
template_profile: {{TEMPLATE_PROFILE}}
template_language: {{TEMPLATE_LANGUAGE}}
---

# 数据库规格

## DDL 与结构变更

记录表、字段、索引、约束、默认值、迁移脚本的变化。

## 表与索引设计

建议至少列出：

| 表/索引 | 用途 | 读写路径 | 是否新增/变更 | 风险 |
|---------|------|----------|---------------|------|
| `t_order` | 订单主表 | application -> mapper | 变更 | 长事务/锁冲突 |
| `idx_order_status` | 状态查询 | query/job | 新增 | 索引维护成本 |

如果有 DDL，建议直接附：

- 建表/改表 SQL
- 索引 SQL
- 回滚 SQL

## 写入链路与一致性

- 哪个服务负责写表
- 写库与删缓存、发消息、审计落库的顺序
- 是否依赖本地事务、唯一索引、幂等表、状态机字段

## 数据迁移与回填

- 是否需要历史数据回填、初始化、修复脚本
- 如何控制批量规模、窗口期和失败重试

## 查询与索引影响

- 新增/修改 SQL 的查询路径
- 索引命中、排序分页、锁竞争、慢查询风险

## 事务与锁风险

- 是否引入长事务、死锁、乐观锁冲突、唯一键冲突
- 是否涉及跨库、分表、分区、归档数据

## 数据风险

说明回填、回滚和兼容性风险。

## 回滚与验证

- 回滚脚本、降级策略、数据兜底方案
- 上线前后要执行的 SQL 验证、数据对账和抽样检查
