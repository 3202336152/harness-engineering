# {{PROJECT_NAME}}

{{DESCRIPTION}}

## 启动检查（每次对话开始时执行）

- 如果 `.harness/` 不存在，且当前请求涉及实现、改代码、补 spec、规划功能或接入约束，先提示“当前项目尚未初始化 harness”，并建议优先运行 `bash scripts/init-harness.sh`。
- 在 harness 初始化完成前，不进入真实功能开发或大规模代码修改；只读分析、答疑、现状梳理可以继续。
- 如果 `.harness/runtime/last-audit.json` 不存在，或其中 `status` 为 `never_run`，在开始较大功能开发、重构或治理前，优先建议先运行一次 `bash scripts/audit-harness.sh` 建立基线。

## 快速命令

```bash
{{STACK_COMMANDS}}
```

## 架构概览

用 2-3 段简要说明项目核心架构，尤其说明：

- 这是单体、多模块还是微服务中的一个服务
- 主要入口是 HTTP、RPC、MQ、Job 还是批处理
- 核心业务逻辑位于哪些模块/包
- 数据、缓存、消息和外部系统的主要交互方式

项目级架构规范见 `docs/project/项目架构.md`。

## 文档导航

- 核心信念与设计决策：`docs/project/核心信念.md`
- 项目级架构：`docs/project/项目架构.md`
- 项目级设计：`docs/project/项目设计.md`
- 项目级接口规范：`docs/project/接口规范.md`
- 项目级开发规范：`docs/project/开发规范.md`
- 项目级测试策略：`docs/project/测试策略.md`
- 项目级安全规范：`docs/project/安全规范.md`
- 文档影响规则：`.harness/doc-impact-rules.json`
- 功能级 spec：`docs/features/`

## 关键约束

> **开始功能开发或进入大规模编码前，必须先确认 spec 和文档前置条件已经满足；未满足时先补文档，再写代码。**

1. 对重要功能变更，或涉及接口、数据库、安全、配置、部署的改动，必须先确认 `docs/features/<feature-id>/` 下已有对应 spec，且没有 `TODO`、`TBD`、`待补充` 等占位内容。
2. 如果缺少功能 spec，先运行 `bash scripts/harness-exec.sh prepare --task "<任务>" --feature-id FEAT-001 --title "<标题>" --agent <agent-name> --json`，或使用 `bash scripts/new-feature-spec.sh ...` 创建 spec 骨架，再进入实现。
3. 修改接口、数据库、安全、配置或部署相关代码前，先对照 `.harness/doc-impact-rules.json`，确认需要同步更新的项目级和功能级文档。
4. 每次提交前都检查 spec、测试和相关文档是否需要同步更新；如果项目已启用 Git hook、Husky 或 CI 门禁，优先让门禁脚本阻断不完整提交。
5. 修改核心基础设施前先查看 `docs/project/核心信念.md`，避免破坏长期稳定的架构决策。
6. 优先复用共享能力，避免复制粘贴式实现；对 Java 项目，优先遵循 `interfaces -> application -> domain -> infrastructure` 的分层边界。

## 自动 Audit 触发条件

- 如果 `.harness/runtime/last-audit.json` 缺失，或 `last_run_at` 距当前已超过 7 天，在继续较大功能开发前优先运行 `bash scripts/audit-harness.sh`。
- 如果用户准备开始新的较大功能、跨模块重构、约束治理或接入 CI/Hook，优先先做一次 audit，再进入实施。
- 如果用户明确表达“文档有点乱”“约束可能失效”“最近项目变复杂了”这类信号，主动运行 audit 并先汇总成熟度等级和优先修复项。

## 初始化后项目文档补全

- `bash scripts/init-harness.sh` 只负责生成骨架和策略文件，不会替代你理解整个项目。
- 对 Java 项目，先运行或刷新 `bash scripts/scan-java-project.sh --json`，确保 `.harness/runtime/java-doc-scan.json` 是最新的。
- 先把扫描结果当成“全量清单”：至少校对 `module_paths`、`package_roots`、`controllers`、`listeners`、`jobs`、`clients`、`application_services`、`domain_services` 是否完整。
- 在补全 `docs/project/` 前，当前编码代理必须先读取扫描清单和关键文件，禁止依赖猜测或只看单个类就下结论。
- 关键深读清单：`pom.xml` / `build.gradle*`、启动类或主入口、`src/main/java` 前两层包结构、主要 `Controller` / `Facade` / `Listener` / `Job`、核心 `ApplicationService` / `DomainService`、`application.yml` / `application-*.yml`。
- 不要求把所有源码全文一次性塞进上下文，但必须先完成全量扫描，再对代表性入口、核心链路、关键配置和主要外部集成点做针对性深读。
- `bash scripts/validate-spec.sh --json --strict` 会基于 Java 扫描基线检查项目文档是否遗漏关键模块、入口、服务和外部依赖。
- 如果仍有未确认的信息，在文档里明确标记“待确认 / 未覆盖范围”，不要编造事实来补满模板。

## Java 项目补充提示

- 不要把核心业务逻辑堆进 Controller、Listener、Job。
- 不要跨领域直接访问不属于自己的底表或私有实现。
- 事务边界、幂等策略、缓存更新、消息发送顺序必须和设计文档保持一致。
- 缺少设计、接口、数据库或测试文档时，先补 spec 再进入大规模实现。
