---
id: project-development
title: 项目开发规范
type: project-development
status: active
owner: {{OWNER}}
last_updated: {{DATE}}
template_version: {{TEMPLATE_VERSION}}
template_profile: {{TEMPLATE_PROFILE}}
template_language: {{TEMPLATE_LANGUAGE}}
---

# 项目开发规范

## 适用范围

本文描述日常开发、联调、评审、发布前准备的统一约定，特别适用于 Java 后端项目。

## 当前模板画像

- 模板版本：`{{TEMPLATE_VERSION}}`
- 模板画像：`{{TEMPLATE_PROFILE}}`
- 画像说明：{{PROFILE_DESCRIPTION}}

## 常用命令

```bash
{{STACK_COMMANDS}}
```

## Java 开发约定

- 统一 JDK 版本、字符集、时区和代码格式化规则。
- 明确使用 Maven/Gradle、Lombok、MapStruct、MyBatis/JPA、Spotless/Checkstyle/PMD 的要求。
- 新模块默认遵循 `interfaces -> application -> domain -> infrastructure` 的分层思路。
- Spring Boot 项目建议使用根包 + 启动类统一扫描，避免默认包和跨仓扫描。
- 入口层默认只做协议转换、参数校验、鉴权上下文接入和日志打点。
- 复杂链路优先写清楚编排服务、规则服务、Mapper/Client 的职责后再开始编码。

## 工程与目录组织

请说明：

- 单模块还是多模块，模块边界如何划分
- `api`、`core`、`infrastructure`、`starter`、`web`、`job` 等模块职责
- 包路径命名、公共模块沉淀原则、禁止循环依赖的规则
- 配置类、定时任务、消息消费者、Feign/HTTP Client 的统一放置位置

## 命名与对象约定

- 包名、类名、方法名、常量名、测试类名的规范
- DTO、Command、Query、Assembler、Converter、Repository、Client 的命名约定
- `BigDecimal`、`LocalDateTime`、`Instant`、枚举状态、分页对象的统一使用方式

## 新增功能最小落地清单

每个复杂 Java 需求默认至少补齐：

1. 功能文档：背景、方案、接口/数据、测试、发布回滚。
2. 入口代码：`controller/listener/job` 与参数校验。
3. 核心编排：`application service` 或同层级服务。
4. 规则实现：领域服务、策略类、转换器、校验器。
5. 数据与集成：Mapper/Repository、Client、缓存、消息、配置。
6. 自动化验证：单测、集成测试、接口测试或关键链路回归命令。
7. 排障信息：日志字段、错误码、关键业务键、必要指标。

## 编码规则

- 优先复用共享能力，避免重复实现。
- 保持文件聚焦且易读。
- 每次有意义的改动都同步更新 spec、文档和测试。
- 接口、数据库、安全、配置、部署相关改动，应满足 `.harness/doc-impact-rules.json` 中的文档联动要求。
- Controller/Listener/Job 不承载核心业务规则。
- 禁止跨领域直接读取不属于自己的底表或私有实现。
- 不为“先跑通”牺牲分层、命名和事务边界。
- 对临时方案、待补逻辑、受限实现必须写清楚 TODO 的业务背景和后续补位点。

## 数据与事务编码约定

- 数据库写操作是否必须走 application service
- 事务注解允许放置的层级、传播行为、只读事务的使用方式
- 批量操作、分布式锁、缓存双删、消息发送的一致性约定
- 说明是否允许事务内调用外部接口，以及事务提交后事件如何发送
- 说明唯一索引、去重表、锁 Key 的统一约定

## 日志、异常与可观测约定

- 错误日志、审计日志、业务日志的边界
- 是否允许 `printStackTrace`、吞异常、重复打错日志
- 关键操作需要输出哪些 trace/span/metric

## 文档与注释同步约定

- 关键类、关键方法、复杂分支必须写“为什么这样做”的说明性注释。
- 调整主链、规则、事务、表结构、消息契约时必须同步更新功能文档。
- 文档中要区分“当前实现”与“目标设计”，不能混写。

## 评审要求

- 记录分支、评审和合并流程要求。
- 说明哪些类型的改动必须附设计文档、接口文档、数据库文档或测试证据。
- 说明本地钩子、PR 模板、CI 门禁是否启用 `check-doc-impact`。
- 说明需要重点检查的 Java 常见问题：长事务、循环依赖、空指针、N+1、反序列化风险、并发覆盖写等。

## 明确禁止事项

- 禁止在 Controller/Listener/Job 中直接堆业务主流程。
- 禁止 Mapper/Repository 中混入业务判断和跨领域编排。
- 禁止缺少业务键就打日志，导致线上问题无法排查。
- 禁止只有代码改动、没有测试和文档同步。
