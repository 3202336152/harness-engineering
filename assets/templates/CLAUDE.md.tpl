# {{PROJECT_NAME}}

{{DESCRIPTION}}

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

1. 修改核心基础设施前先查看 `docs/project/核心信念.md`。
2. 每次有意义的改动都同步更新测试和文档。
3. 优先复用共享能力，避免复制粘贴式实现。
4. 对重要功能变更，在 `docs/features/` 下创建或更新功能级 spec。
5. 对 Java 项目，优先遵循 `interfaces -> application -> domain -> infrastructure` 的分层边界。
6. 如果修改了接口、数据库、安全、配置或部署相关代码，提交前对照 `.harness/doc-impact-rules.json` 检查需要同步更新的文档。

## Java 项目补充提示

- 不要把核心业务逻辑堆进 Controller、Listener、Job。
- 不要跨领域直接访问不属于自己的底表或私有实现。
- 事务边界、幂等策略、缓存更新、消息发送顺序必须和设计文档保持一致。
- 缺少设计、接口、数据库或测试文档时，先补 spec 再进入大规模实现。
