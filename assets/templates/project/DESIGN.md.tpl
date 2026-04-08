---
id: project-design
title: 项目设计原则
type: project-design
status: active
owner: {{OWNER}}
last_updated: {{DATE}}
template_version: {{TEMPLATE_VERSION}}
template_profile: {{TEMPLATE_PROFILE}}
template_language: {{TEMPLATE_LANGUAGE}}
---

# 项目设计

## 设计目标

总结该项目在长期演进中要持续守住的目标，例如：

- 业务规则集中而不是分散在 Controller/Job/Listener 中
- 技术实现可替换，核心领域规则尽量稳定
- 关键流程具备可观测、可回放、可补偿能力

## Java 分层设计约定

建议说明以下内容：

- `controller / rpc / listener / job` 是否统一归入接口层
- `application service` 与 `domain service` 的职责划分
- `repository`、`mapper`、`dao`、`gateway` 的命名和定位
- `config`、`starter`、`support`、`common` 包的进入门槛
- 多模块项目如何拆分 parent/module/api/core/adapter

## 对象模型与命名约定

建议至少覆盖：

- `Request / Response / DTO / Command / Query / VO / DO / Entity / Enum`
- 哪些对象允许跨层传递，哪些必须在边界处转换
- 集合、分页、金额、时间、状态字段的统一表达方式
- 是否统一使用 Lombok、MapStruct、Builder、Record 等

## 持久化与数据设计约定

请说明：

- MyBatis XML、注解 Mapper、JPA Repository 的适用边界
- SQL 放置位置、命名规则、慢查询治理方式
- 乐观锁/悲观锁、唯一索引、状态机字段的使用约定
- 读模型和写模型是否分离，是否允许直接返回数据库对象

## 异常、错误码与可恢复性设计

- 业务异常、系统异常、第三方异常如何分层定义
- 是否统一错误码枚举和对外错误响应模型
- 哪些异常允许重试，哪些必须快速失败
- 补偿、回查、人工介入的触发条件

## 集成与异步设计约定

- HTTP/RPC client 的封装规范
- 事件、消息、任务调度的命名和投递约定
- 出站事件是否采用 Outbox 或可靠消息方案
- 调用链中如何做超时、重试、熔断、隔离和降级

## 性能与扩展性关注点

记录团队在设计评审时必须主动检查的事项：

- N+1 查询、批量写入、索引缺失、长事务、全表扫描
- 热点缓存、热点 Key、消息积压、线程池耗尽
- 大对象序列化、深层对象拷贝、反射滥用
- 横向扩容、分库分表、多租户、灰度发布兼容性

## 设计决策记录

将重要决策关联到 `docs/decisions/` 或 `docs/design-docs/`，并说明：

- 决策背景
- 可选方案
- 最终选择
- 主要 trade-off
- 后续可演进方向
