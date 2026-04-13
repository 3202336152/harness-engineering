# harness-engineering

`harness-engineering` 是一个面向 AI 编码代理的 Agent Skill，用来为项目建立清晰的约束、共享文档结构和可执行的验证闭环。它把 Harness Engineering 的核心能力做成可安装、可脚本化、可接入本地与 CI 的工具集。

这个仓库适合以下场景：

- 需要为 AI 编码代理初始化统一的项目入口、规范和策略文件
- 希望把文档影响检查、架构约束、spec 校验接成本地或 CI 门禁
- 希望为功能开发建立 `prepare -> verify -> run -> restore` 的基础自治闭环

## 核心能力

- `/harness init`
  为项目生成入口文档、`harness/` 目录结构、项目级/功能级 spec 模板和策略文件。
- `/harness audit`
  评估当前 Harness 成熟度，并可选执行深度检查。
- `/harness plan`
  生成 Markdown 执行计划和机器可读 JSON plan。
- `scripts/harness-exec.sh`
  提供 `prepare`、`verify`、`run`、`restore` 四个阶段的自治入口。

设计上有两个关键原则：

- 项目共享文档放在 `harness/docs/`，运行期状态放在 `harness/.harness/`，避免和业务仓库已有目录冲突。
- 规则尽量通过脚本和 JSON 策略落地，而不是只停留在说明文档里。

## 主要特性

- 初始化项目级与功能级 spec 结构
- 支持文档影响检查、spec 校验、架构 lint、回滚准备度检查
- 支持模板覆写、模板漂移检查和安全迁移
- 支持任务上下文解析、上下文 bundle、运行记录、证据采集和 GC
- 支持 Java 项目扫描，辅助项目文档补全和严格校验

## 运行前提

- `bash`
- `git`
- `jq`

建议第一次在新机器使用前先执行：

```bash
bash scripts/check-runtime-deps.sh --json
```

Windows 环境建议通过 WSL2 或其他兼容 POSIX 的 Shell 使用。

## 安装

本地开发或试点，推荐直接使用仓库自带脚本：

```bash
bash scripts/install-skill.sh --global
```

这个脚本会先检查依赖，再导出 runtime-only Skill 包并安装到全局目录。

如果你希望直接从远程仓库安装：

```bash
npx skills add 3202336152/harness-engineering
```

## 快速开始

初始化一个项目的 Harness 基础结构：

```bash
bash scripts/init-harness.sh --with-strong-constraints
```

查看当前 Harness 成熟度：

```bash
bash scripts/audit-harness.sh --deep
```

为一个具体功能生成 spec、计划和上下文：

```bash
bash scripts/harness-exec.sh prepare \
  --task "实现订单查询接口" \
  --feature-id FEAT-001 \
  --title "订单查询" \
  --json
```

执行一轮聚合校验或完整运行：

```bash
bash scripts/harness-exec.sh verify --feature-id FEAT-001 --json
bash scripts/harness-exec.sh run \
  --task "实现订单查询接口" \
  --feature-id FEAT-001 \
  --title "订单查询" \
  --json
```

## 仓库结构

- `SKILL.md`: Skill 入口和能力定义
- `scripts/`: 核心脚本实现
- `assets/templates/`: 初始化模板和策略模板
- `assets/hooks/`: 本地 Hook 模板
- `assets/ci-templates/`: CI 模板
- `schemas/`: 机器可读 schema
- `doc/`: 面向维护者和使用者的详细文档
- `references/`: 参考资料
- `tests/`: 本地测试

## 文档入口

如果你要继续深入了解，建议从这里开始：

- [doc/本地使用指南.md](./doc/本地使用指南.md)
- [doc/命令使用说明.md](./doc/命令使用说明.md)
- [doc/能力与功能说明.md](./doc/能力与功能说明.md)
- [doc/安装与试点指南.md](./doc/安装与试点指南.md)
- [references/MATURITY-MODEL.md](./references/MATURITY-MODEL.md)

## 本地验证

```bash
bash tests/run-tests.sh
bash scripts/verify-spec-compliance.sh
```

## License

MIT
