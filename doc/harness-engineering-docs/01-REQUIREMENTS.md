# 01 -- 需求分析

> Harness Engineering Skill | 版本 1.0

---

## 1. 背景与动机

### 1.1 问题陈述

AI 编码代理（Codex / Claude Code / Cursor 等）的效能瓶颈不在模型能力，而在项目环境质量。OpenAI 在 2026 年 2 月发表的 Harness Engineering 理念指出：

```
编码代理 = AI 模型 + Harness
```

模型正在商品化，Harness 才是真正的竞争壁垒。然而当前大多数项目缺少：

- 结构化的 Agent 入口文档（AGENTS.md / CLAUDE.md）
- 机械化的架构约束（CI 执行而非文档劝告）
- 可观测的反馈循环（结构化日志、浏览器自动化）
- 系统化的熵管理（文档新鲜度、死代码清理）

工程师需要手动搭建这些基础设施，过程繁琐且缺乏标准。

### 1.2 解决方案

构建一个遵循 Agent Skills 开放标准（agentskills.io）的 Skill，通过 skills.sh 分发，可被 40+ AI 编码代理自动加载，提供 Harness 的初始化、审计和任务规划能力。

---

## 2. 目标用户与使用场景

### 2.1 用户画像

| 用户类型 | 痛点 | 期望 |
|----------|------|------|
| 独立开发者 | 新项目无 Harness，Agent 每次从零理解项目 | 一条命令搭建完整结构 |
| 团队 Tech Lead | 不知道团队的 Harness 成熟度如何 | 量化评估 + 优先级修复建议 |
| AI 编码代理 | 缺少结构化的项目上下文 | 被调用后自动初始化/审计 |
| 开源维护者 | 希望贡献者的 Agent 能理解项目 | 标准化的文档结构 |

### 2.2 用户故事

**US-01**: 作为独立开发者，我希望在新项目中运行 `/harness init`，自动生成 AGENTS.md、docs/ 结构和模板文件，以便 AI 代理能立即理解项目。

**US-02**: 作为 Tech Lead，我希望运行 `/harness audit` 对现有项目的 Harness 健康度进行评分，获得按优先级排列的改进建议。

**US-03**: 作为 AI 编码代理，我希望在检测到项目缺少 Harness 结构时自动触发初始化流程。

**US-04**: 作为开发者，我希望运行 `/harness plan <任务描述>` 生成符合"目标+约束+验收标准"格式的执行计划。

**US-05**: 作为开发者，我希望通过 `npx skills add <owner>/harness-engineering` 一键安装此 Skill。

**US-06**: 作为跨工具用户，我希望此 Skill 在 Claude Code、Codex、Cursor 等工具中均可使用。

---

## 3. 功能需求

### 3.1 Phase 1 -- 核心功能（本次实施范围）

| ID | 功能 | 描述 | 优先级 |
|----|------|------|--------|
| F-01 | Harness 初始化 | 检测项目状态，生成 AGENTS.md、CLAUDE.md、docs/ 结构、PR 模板 | P0 |
| F-02 | 技术栈检测 | 自动识别 Node/Python/Go/Rust 并填充对应命令 | P0 |
| F-03 | 幂等初始化 | 已有文件不覆盖（除非 --force）| P0 |
| F-04 | Dry-run 模式 | --dry-run 仅打印操作不实际执行 | P1 |
| F-05 | Harness 审计 | 8 维度评分，输出结构化 JSON 报告 | P0 |
| F-06 | 成熟度等级 | Level 0-4 映射和升级建议 | P0 |
| F-07 | 修复建议 | 每个审计缺陷附带具体修复步骤 | P0 |
| F-08 | 任务规划 | 生成符合 Harness 规范的执行计划文档 | P1 |
| F-09 | SKILL.md 入口 | 符合 Agent Skills 规范的入口文件 | P0 |
| F-10 | 成熟度参考 | MATURITY-MODEL.md 深层参考文档 | P0 |

### 3.2 Phase 2 & 3 -- 后续功能（本次不实施，仅设计接口）

| ID | 功能 | 阶段 |
|----|------|------|
| F-11 | 架构边界校验脚本 (lint-architecture.sh) | Phase 3 |
| F-12 | 文档新鲜度检查 (check-doc-freshness.sh) | Phase 3 |
| F-13 | 深层参考文档 (ARCHITECTURE-PATTERNS.md 等 9 篇) | Phase 2-3 |
| F-14 | CI 模板 (GitHub Actions / GitLab CI) | Phase 3 |

---

## 4. 非功能需求

| 类别 | 要求 | 验证方式 |
|------|------|----------|
| 兼容性 | 符合 Agent Skills 规范 (agentskills.io/specification) | skills-ref validate |
| 兼容性 | 通过 `npx skills add` 安装后可被 Agent 自动识别 | 手动验证 |
| 可移植性 | 脚本仅依赖 bash + git + grep/find/sed/awk/jq | 在 Alpine/Ubuntu/macOS 验证 |
| 幂等性 | 所有脚本重复运行不破坏现有内容 | 重复执行测试 |
| 结构化输出 | 所有脚本输出 JSON，Agent 可解析 | jq 解析验证 |
| 渐进式披露 | SKILL.md < 500 行，reference 文件按需加载 | 行数检查 |
| 语言无关 | 不假设项目使用特定语言/框架 | 多语言项目测试 |
| 安全 | 不执行破坏性操作，不接触 .env / credentials | 代码审查 |
| 性能 | init 脚本执行 < 5 秒，audit 脚本执行 < 10 秒 | 计时验证 |

---

## 5. 验收标准总览

### 5.1 Phase 1 完成标准

- [ ] SKILL.md 通过 `skills-ref validate ./harness-engineering`
- [ ] `npx skills add <owner>/harness-engineering` 安装成功
- [ ] 在空 git 仓库运行 init 后生成完整 Harness 结构
- [ ] 在已有 AGENTS.md 的项目运行 init 不覆盖文件
- [ ] --dry-run 模式不创建任何文件
- [ ] --force 模式覆盖已有文件
- [ ] audit 在 Level 0 项目输出 0 分
- [ ] audit 在完整 Harness 项目输出 90+ 分
- [ ] audit 输出的 JSON 可被 jq 正常解析
- [ ] 每个审计缺陷有对应的修复建议
- [ ] 脚本在 macOS (zsh) 和 Linux (bash) 均可运行
- [ ] SKILL.md body < 500 行
- [ ] Node/Python/Go/Rust 四种技术栈均可正确检测

### 5.2 skills.sh 发布标准

- [ ] 仓库名与 skill name 一致: `harness-engineering`
- [ ] name 字段符合规范（小写+连字符，无连续连字符）
- [ ] description 字段 < 1024 字符，包含触发关键词
- [ ] 目录名与 name 字段一致
- [ ] 可通过 `npx skills add` 安装到至少 Claude Code 和 Codex

---

## 6. 约束与边界

### 6.1 本 Skill 做什么

- 提供 Harness 结构的脚手架和模板
- 审计 Harness 健康度并给出修复建议
- 生成符合 Harness 规范的任务执行计划
- 提供成熟度模型参考

### 6.2 本 Skill 不做什么

- 不替代语言特定的 linter（ESLint / ruff / golangci-lint）
- 不替代测试框架（Jest / pytest / go test）
- 不提供 CI/CD 完整实现（只提供模板）
- 不自动修改业务代码
- 不处理部署和生产环境操作
- 不管理 Agent 的模型选择或 token 预算

---

## 7. 开放问题决策记录

| 问题 | 决策 | 理由 |
|------|------|------|
| Skill 名称 | `harness-engineering` | 语义明确，skills.sh 上易搜索 |
| 配置文件位置 | `.harness/architecture.json` | 专用目录不污染根目录 |
| 多语言模板策略 | 一套通用模板 + 技术栈检测自动填充 | 维护成本低，覆盖面广 |
| 审计是否自动修复 | 脚本只输出报告，修复由 Agent 执行 | 更灵活，避免意外修改 |
| 分发方式 | GitHub 仓库 + skills.sh 索引 | 社区标准做法 |
