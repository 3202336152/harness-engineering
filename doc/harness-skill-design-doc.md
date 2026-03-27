# Harness Engineering Skill -- 实施设计文档

> 状态: 待评审
> 版本: 0.1
> 日期: 2026-03-27

---

## 1. 目标与定位

### 1.1 Skill 要解决的问题

当前 AI 编码代理（Codex / Claude Code / Cursor 等）的效能瓶颈不是模型能力，而是项目环境的质量。大多数项目缺少：

- 结构化的 Agent 入口文档
- 机械化的架构约束
- 可观测的反馈循环
- 系统化的熵管理

工程师需要手动搭建这些基础设施，过程繁琐且缺乏标准。

### 1.2 Skill 的定位

一个**通用的、跨工具的 Harness Engineering 脚手架和守护工具**。

- 不绑定特定语言或框架
- 不替代具体的 linter/测试工具，而是提供"元层"指导
- 帮助工程师从零建立 Harness，也帮助已有项目评估和改进

### 1.3 目标用户

| 用户类型 | 使用场景 |
|----------|----------|
| 独立开发者 | 新项目快速搭建 Harness 结构 |
| 团队 Tech Lead | 评估现有项目的 Harness 成熟度，规划改进路径 |
| AI 编码代理 | 被调用后自动执行 Harness 初始化/审计/清理 |

---

## 2. 兼容性与分发

### 2.1 遵循标准

遵循 **Agent Skills 开放标准**（agentskills.io, 2025.12 发布），核心格式为 SKILL.md。

### 2.2 兼容平台

| 平台 | 安装路径 | 调用方式 |
|------|----------|----------|
| Claude Code | `~/.claude/skills/harness-engineering/` | `/harness` 或自动触发 |
| OpenAI Codex | `~/.codex/skills/harness-engineering/` | 自动触发 |
| VS Code Copilot | `chatSkills` 贡献点 | `/harness` |
| Cursor | `~/.claude/skills/harness-engineering/` | 自动触发 |
| Gemini CLI | 手动加载 | 引用 SKILL.md 内容 |

### 2.3 分发方式

- GitHub 仓库（主要）
- 用户 clone 后 symlink 或复制到各工具的 skills 目录
- 未来可提交到 skillsmp.com 等 Skill 市场

---

## 3. 目录结构设计

```
harness-engineering/
│
├── SKILL.md                         # [必须] 入口文件，<500行
│                                    #   - YAML frontmatter（元数据）
│                                    #   - Markdown body（核心指令）
│
├── scripts/                         # [可选] 可执行脚本
│   ├── init-harness.sh              #   初始化 Harness 项目结构
│   ├── audit-harness.sh             #   审计 Harness 健康度
│   ├── lint-architecture.sh         #   架构边界校验（通用版）
│   └── check-doc-freshness.sh       #   文档新鲜度检查
│
├── references/                      # [可选] 深层参考文档（按需加载）
│   ├── ARCHITECTURE-PATTERNS.md     #   分层架构模式详解
│   ├── AGENTS-MD-GUIDE.md           #   AGENTS.md 编写指南与模板
│   ├── CONTEXT-ENGINEERING.md       #   上下文工程实践
│   ├── OBSERVABILITY.md             #   可观测性集成指南
│   ├── ENTROPY-MANAGEMENT.md        #   熵管理策略
│   ├── TASK-SPEC-FORMAT.md          #   任务指令格式规范
│   ├── PR-WORKFLOW.md               #   PR 工作流与模板
│   ├── METRICS.md                   #   度量体系
│   ├── SECURITY.md                  #   安全与治理
│   └── MATURITY-MODEL.md            #   Harness 成熟度模型
│
└── assets/                          # [可选] 静态资源
    ├── templates/                   #   可复制的项目模板
    │   ├── AGENTS.md.tpl            #     AGENTS.md 模板
    │   ├── CLAUDE.md.tpl            #     CLAUDE.md 模板
    │   ├── CONVENTIONS.md.tpl       #     编码规范模板
    │   ├── ARCHITECTURE.md.tpl      #     架构文档模板
    │   ├── TESTING.md.tpl           #     测试策略模板
    │   └── PR_TEMPLATE.md.tpl       #     PR 模板
    └── ci-templates/                #   CI 配置模板
        ├── github-actions.yml.tpl   #     GitHub Actions
        └── gitlab-ci.yml.tpl        #     GitLab CI
```

---

## 4. SKILL.md 设计

### 4.1 Frontmatter

```yaml
---
name: harness-engineering
description: >
  Harness Engineering 工具集：初始化、审计和维护 AI 编码代理的工作环境。
  用于为项目搭建 AGENTS.md、架构约束、反馈循环和熵管理体系。
  触发条件：用户提到"harness"、"初始化项目结构"、"AGENTS.md"、
  "架构约束"、"代码审计"、"熵管理"、"Harness 成熟度"，
  或要求为 AI 代理优化项目环境时使用。
license: MIT
compatibility: 需要 bash 和 git。适用于任何语言/框架的项目。
metadata:
  author: [你的名字/团队]
  version: "1.0.0"
  tags:
    - harness-engineering
    - agent-environment
    - scaffolding
    - code-quality
allowed-tools: Bash(git:*) Read Write Edit Glob Grep
---
```

### 4.2 Body 结构规划（~400行）

SKILL.md body 分为以下段落，控制总量在 400-500 行：

```
# Harness Engineering

## 概述（~20行）
  - 什么是 Harness Engineering，一段话定义
  - 核心公式：编码代理 = AI 模型 + Harness
  - 本 Skill 提供的三大能力

## 能力一：初始化 /harness init（~80行）
  - 触发条件
  - 执行流程（7步）
  - 脚本调用方式
  - 输出产物清单
  - 初始化后的引导提示

## 能力二：审计 /harness audit（~80行）
  - 触发条件
  - 审计维度（8个）
  - 评分规则
  - 脚本调用方式
  - 输出格式（结构化报告）
  - 修复建议生成规则

## 能力三：任务规划 /harness plan（~60行）
  - 触发条件
  - 输入格式
  - 输出格式（执行计划模板）
  - 与 exec-plans/ 目录的集成

## 架构约束速查（~60行）
  - 分层模型速查表
  - 依赖方向规则
  - 跨域通信规则
  - 指向 references/ARCHITECTURE-PATTERNS.md 的链接

## 上下文工程速查（~40行）
  - AGENTS.md 编写原则（100行上限、索引式、渐进披露）
  - 知识必须在仓库中
  - 指向 references/CONTEXT-ENGINEERING.md 的链接

## 熵管理速查（~30行）
  - 黄金原则清单
  - 自动清理策略
  - 指向 references/ENTROPY-MANAGEMENT.md 的链接

## 反模式清单（~30行）
  - 10个常见反模式，每个一行描述
```

---

## 5. 脚本设计

### 5.1 设计原则

| 原则 | 说明 |
|------|------|
| 零依赖 | 仅依赖 bash + git + 常见 Unix 工具（grep/find/sed/awk/jq） |
| 幂等性 | 重复运行不破坏现有内容（已有文件不覆盖，除非显式指定） |
| 结构化输出 | 所有脚本输出 JSON 格式的结果，Agent 可解析 |
| 错误即指导 | 每个错误/警告都附带修复建议 |
| 语言无关 | 不假设项目使用特定语言/框架 |

### 5.2 init-harness.sh

**功能：** 在当前项目中初始化 Harness 结构。

**输入参数：**

| 参数 | 必须 | 说明 |
|------|------|------|
| `--project-name` | 否 | 项目名称，默认取目录名 |
| `--description` | 否 | 项目描述 |
| `--force` | 否 | 覆盖已有文件 |
| `--dry-run` | 否 | 仅打印将要执行的操作，不实际执行 |

**执行流程：**

```
1. 检测当前目录是否为 git 仓库
2. 检测是否已有 AGENTS.md / CLAUDE.md（避免覆盖）
3. 创建 docs/ 目录结构
   - docs/ARCHITECTURE.md
   - docs/CONVENTIONS.md
   - docs/TESTING.md
   - docs/SECURITY.md
   - docs/design-docs/core-beliefs.md
   - docs/exec-plans/{active,completed,tech-debt}/
   - docs/product-specs/
   - docs/references/
4. 从 assets/templates/ 复制并填充模板
   - AGENTS.md（填入项目名和描述）
   - CLAUDE.md（同步）
5. 创建 .github/PULL_REQUEST_TEMPLATE.md
6. 检测项目类型并生成技术栈相关提示
   - 检测 package.json -> 提示 Node.js 相关命令
   - 检测 pyproject.toml/setup.py -> 提示 Python 相关命令
   - 检测 Cargo.toml -> 提示 Rust 相关命令
   - 检测 go.mod -> 提示 Go 相关命令
   - 未检测到 -> 提供通用占位符
7. 输出初始化报告（JSON格式）
```

**输出示例：**

```json
{
  "status": "success",
  "project": "my-app",
  "created_files": [
    "AGENTS.md",
    "CLAUDE.md",
    "docs/ARCHITECTURE.md",
    "docs/CONVENTIONS.md",
    "docs/TESTING.md",
    "docs/SECURITY.md",
    "docs/design-docs/core-beliefs.md",
    ".github/PULL_REQUEST_TEMPLATE.md"
  ],
  "created_dirs": [
    "docs/exec-plans/active",
    "docs/exec-plans/completed",
    "docs/exec-plans/tech-debt",
    "docs/product-specs",
    "docs/references"
  ],
  "skipped_files": [],
  "detected_stack": "node",
  "next_steps": [
    "编辑 AGENTS.md 填入项目的具体架构信息",
    "编辑 docs/ARCHITECTURE.md 描述系统设计",
    "编辑 docs/CONVENTIONS.md 定义编码规范",
    "在 CI 中添加 Harness 校验（参考 assets/ci-templates/）"
  ]
}
```

### 5.3 audit-harness.sh

**功能：** 审计当前项目的 Harness 健康度，输出评分报告。

**审计维度（8个）：**

| 维度 | 权重 | 检查项 |
|------|------|--------|
| 入口文档 | 15% | AGENTS.md 或 CLAUDE.md 是否存在、行数是否 <100、是否包含核心段落 |
| 文档结构 | 15% | docs/ 目录是否存在、核心文档是否齐全（ARCHITECTURE/CONVENTIONS/TESTING/SECURITY） |
| 文档新鲜度 | 10% | docs/ 中文件的最后修改时间，超过 30 天标记为过期 |
| 架构约束 | 15% | 是否存在架构校验脚本或 linter 配置、CI 中是否集成 |
| 测试覆盖 | 15% | 是否有测试命令配置、测试目录是否存在、是否有 CI 测试步骤 |
| 自动化检查 | 10% | pre-commit hook 是否配置、CI 流水线是否存在 |
| 执行计划 | 10% | exec-plans/ 目录是否存在、是否有活跃计划 |
| 安全治理 | 10% | .env 是否在 .gitignore 中、是否有 SECURITY.md |

**评分规则：**

```
每个维度独立打分 0-100：
  - 100: 完全满足
  - 75:  大部分满足，有小改进空间
  - 50:  基本框架存在但不完整
  - 25:  仅有雏形
  - 0:   完全缺失

总分 = 各维度加权平均

成熟度等级映射：
  90-100: Level 4 - 自主 Harness
  70-89:  Level 3 - 可观测 Harness
  50-69:  Level 2 - 约束 Harness
  25-49:  Level 1 - 基础 Harness
  0-24:   Level 0 - 无 Harness
```

**输出示例：**

```json
{
  "status": "completed",
  "overall_score": 42,
  "maturity_level": 1,
  "maturity_label": "基础 Harness",
  "dimensions": {
    "entry_document": {
      "score": 75,
      "status": "AGENTS.md 存在，但超过 100 行（当前 156 行）",
      "fix": "精简 AGENTS.md 至 100 行以内，将详细内容移至 docs/"
    },
    "doc_structure": {
      "score": 50,
      "status": "docs/ 存在，但缺少 TESTING.md 和 SECURITY.md",
      "fix": "创建 docs/TESTING.md 和 docs/SECURITY.md"
    },
    "doc_freshness": {
      "score": 25,
      "status": "3/5 个文档超过 30 天未更新",
      "stale_files": ["docs/ARCHITECTURE.md", "docs/CONVENTIONS.md", "docs/design-docs/core-beliefs.md"],
      "fix": "审查并更新过期文档，确保与当前代码一致"
    },
    "architecture_constraints": {
      "score": 0,
      "status": "未检测到架构校验脚本或结构化 linter",
      "fix": "参考 references/ARCHITECTURE-PATTERNS.md 添加架构边界校验"
    },
    "test_coverage": {
      "score": 75,
      "status": "测试命令存在，测试目录存在，但 CI 中未集成测试步骤",
      "fix": "在 CI 流水线中添加测试步骤"
    },
    "automation": {
      "score": 50,
      "status": "CI 流水线存在，但未配置 pre-commit hook",
      "fix": "配置 pre-commit hook 运行 lint 和格式化"
    },
    "exec_plans": {
      "score": 0,
      "status": "无 exec-plans/ 目录",
      "fix": "创建 docs/exec-plans/{active,completed,tech-debt}/ 目录结构"
    },
    "security_governance": {
      "score": 50,
      "status": ".env 已在 .gitignore 中，但缺少 SECURITY.md",
      "fix": "创建 docs/SECURITY.md 文档"
    }
  },
  "priority_fixes": [
    { "priority": 1, "action": "添加架构边界校验脚本并集成到 CI", "impact": "high" },
    { "priority": 2, "action": "创建 docs/exec-plans/ 执行计划目录", "impact": "medium" },
    { "priority": 3, "action": "精简 AGENTS.md 至 100 行以内", "impact": "medium" },
    { "priority": 4, "action": "更新 3 个过期文档", "impact": "low" }
  ]
}
```

### 5.4 lint-architecture.sh

**功能：** 通用架构边界校验。

**设计挑战：** 不同语言的 import 语法不同，需要通用化。

**方案：** 采用**配置驱动**而非硬编码。脚本读取项目根目录下的 `.harness/architecture.json` 配置文件（由 init 生成骨架，用户填充具体规则）。

**配置文件格式：**

```json
{
  "layers": ["types", "config", "repo", "service", "runtime", "ui"],
  "layer_direction": "left-to-right",
  "domains": ["user", "order", "payment"],
  "cross_domain_allowed_via": "providers",
  "import_patterns": {
    "typescript": "from ['\"]\\./",
    "python": "^(from|import) ",
    "go": "import ",
    "generic": "(import|require|include|use) "
  },
  "src_root": "src",
  "custom_rules": []
}
```

**执行流程：**

```
1. 读取 .harness/architecture.json（不存在则输出引导信息并退出）
2. 根据配置的层次和方向，构建"禁止依赖"矩阵
3. 扫描 src_root 下的文件，匹配 import_patterns
4. 对每个 import 检查是否违反层次方向
5. 对每个跨域 import 检查是否通过 providers
6. 输出违规清单（JSON格式），每条附带修复建议
```

**注意：** 此脚本提供基础通用能力。对于复杂项目，建议用户使用语言原生的 linter 插件（如 ESLint 的 import/no-restricted-paths），本脚本的价值在于提供通用的起点和配置骨架。

### 5.5 check-doc-freshness.sh

**功能：** 检查 docs/ 目录中文档的新鲜度。

**执行流程：**

```
1. 扫描 docs/ 下所有 .md 文件
2. 通过 git log 获取每个文件的最后修改时间
3. 与关联的代码文件对比修改时间（如果 docs/TESTING.md 关联 tests/）
4. 超过阈值（默认30天）的标记为 stale
5. 输出报告（JSON格式）
```

**输入参数：**

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `--threshold` | 30 | 过期天数阈值 |
| `--path` | docs/ | 扫描路径 |
| `--json` | false | 输出 JSON 格式 |

---

## 6. Reference 文档设计

每个 reference 文档是 SKILL.md body 中某个领域的深度展开。Agent 在需要时按需加载。

### 6.1 文档清单与内容规划

| 文件 | 预计行数 | 核心内容 |
|------|----------|----------|
| ARCHITECTURE-PATTERNS.md | ~200行 | 分层模型详解；依赖方向规则；Providers 模式；边界校验策略；配置文件编写指南；不同语言的实现差异 |
| AGENTS-MD-GUIDE.md | ~150行 | AGENTS.md 的完整编写指南；段落结构要求；好/坏示例对比；100行原则的详细解释；与 CLAUDE.md/.cursorrules 的同步策略 |
| CONTEXT-ENGINEERING.md | ~150行 | 上下文预算概念；渐进式披露的三层模型；知识迁移清单（从 Slack/Docs/脑中到仓库）；Sub-Agent 策略 |
| OBSERVABILITY.md | ~150行 | Bootable Worktree 配置方法；浏览器自动化集成（Playwright/Puppeteer）；结构化日志格式规范；本地指标查询方法 |
| ENTROPY-MANAGEMENT.md | ~120行 | 黄金原则定义方法；自动清理代理的配置；文档新鲜度管理；死代码检测策略；定期清理任务的调度 |
| TASK-SPEC-FORMAT.md | ~100行 | 任务指令的标准格式（目标+约束+验收）；执行计划模板；好/坏指令对比示例 |
| PR-WORKFLOW.md | ~100行 | PR 模板；合并哲学（传统 vs Agent-First）；审查策略转变；3.5 PR/天的实现路径 |
| METRICS.md | ~100行 | 四类指标定义（吞吐量/质量/人工注意力/Harness健康）；目标值设定；指标采集方法 |
| SECURITY.md | ~80行 | 最小权限矩阵；审计追踪要求；快速回滚机制；Agent 权限配置 |
| MATURITY-MODEL.md | ~80行 | Level 0-4 的完整定义；每级的检查清单；升级路径和时间线建议 |

### 6.2 编写规范

所有 reference 文档遵循统一格式：

```markdown
# [主题名称]

> 本文档是 harness-engineering skill 的深层参考。
> 由 SKILL.md 按需引用加载。

## 概述
[2-3句话说明本文档覆盖什么]

## 核心概念
[关键定义和原理]

## 实施步骤
[具体的操作指南]

## 示例
[好/坏对比、代码片段、配置模板]

## 常见问题
[FAQ]

## 相关文档
[指向其他 reference 的链接]
```

---

## 7. 模板文件设计

### 7.1 assets/templates/ 模板清单

每个 `.tpl` 文件是一个可复制的模板，其中用 `{{变量名}}` 标记需要填充的位置。

| 模板文件 | 用途 | 变量 |
|----------|------|------|
| AGENTS.md.tpl | 项目 Agent 入口文件 | `{{PROJECT_NAME}}`, `{{DESCRIPTION}}`, `{{STACK_COMMANDS}}` |
| CLAUDE.md.tpl | Claude Code 入口文件 | 同上 |
| CONVENTIONS.md.tpl | 编码规范 | `{{LANGUAGE}}`, `{{FRAMEWORK}}` |
| ARCHITECTURE.md.tpl | 架构文档 | `{{PROJECT_NAME}}`, `{{DOMAINS}}` |
| TESTING.md.tpl | 测试策略 | `{{TEST_COMMAND}}`, `{{COVERAGE_TOOL}}` |
| PR_TEMPLATE.md.tpl | PR 模板 | 无变量，直接可用 |

### 7.2 CI 模板

| 模板文件 | 用途 |
|----------|------|
| github-actions.yml.tpl | GitHub Actions Harness 校验流水线 |
| gitlab-ci.yml.tpl | GitLab CI Harness 校验流水线 |

CI 模板包含以下阶段：
1. 架构边界校验
2. 文档新鲜度检查
3. 测试运行
4. 类型检查（如适用）
5. Lint 检查

---

## 8. 交互流程设计

### 8.1 场景一：新项目初始化

```
用户: "帮我初始化 Harness 结构" 或 "/harness init"

Agent 行为:
  1. 检测项目状态（git? 已有 AGENTS.md?）
  2. 检测技术栈（package.json? pyproject.toml?）
  3. 运行 scripts/init-harness.sh --project-name=xxx
  4. 解析 JSON 输出
  5. 向用户报告创建了哪些文件
  6. 提示用户下一步需要填充的内容
  7. 如果用户要求，帮助填充 AGENTS.md 和 docs/ 中的文档内容
```

### 8.2 场景二：审计现有项目

```
用户: "检查一下我的 Harness 状态" 或 "/harness audit"

Agent 行为:
  1. 运行 scripts/audit-harness.sh --json
  2. 解析 JSON 输出
  3. 展示评分总览和成熟度等级
  4. 按优先级列出改进项
  5. 询问用户是否要自动修复某些项
  6. 如果用户同意，按优先级依次执行修复
```

### 8.3 场景三：任务规划

```
用户: "按 Harness 规范帮我规划这个功能的实现" 或 "/harness plan 添加用户搜索功能"

Agent 行为:
  1. 加载 references/TASK-SPEC-FORMAT.md
  2. 读取项目的 docs/ARCHITECTURE.md 了解架构
  3. 生成符合"目标+约束+验收标准"格式的执行计划
  4. 将计划写入 docs/exec-plans/active/
  5. 展示计划供用户审核
```

### 8.4 自动触发条件

SKILL.md 的 description 中定义了触发关键词，Agent 在以下情况自动加载此 Skill：

- 用户提到 "harness"、"AGENTS.md"、"架构约束"
- 用户要求 "初始化项目结构"、"搭建开发环境"
- 用户要求 "代码审计"、"项目健康检查"
- 用户提到 "熵管理"、"文档过期"、"架构漂移"
- 用户要求为 AI 编码代理 "优化项目环境"

---

## 9. 约束与边界

### 9.1 本 Skill 做什么

- 提供 Harness 结构的脚手架和模板
- 审计 Harness 的健康度并给出修复建议
- 生成符合 Harness 规范的任务执行计划
- 提供通用的架构边界校验基础能力
- 提供全套 reference 文档供 Agent 按需学习

### 9.2 本 Skill 不做什么

- 不替代语言特定的 linter（ESLint / ruff / golangci-lint）
- 不替代测试框架（Jest / pytest / go test）
- 不提供 CI/CD 的完整实现（只提供模板）
- 不自动修改业务代码
- 不处理部署和生产环境操作
- 不管理 Agent 的模型选择或 token 预算

### 9.3 技术约束

- 脚本仅依赖 bash + git + 常见 Unix 工具
- 不需要安装额外的包管理器或运行时
- SKILL.md body 控制在 500 行以内
- 每个 reference 文档控制在 200 行以内
- 所有脚本输出 JSON 格式，便于 Agent 解析

---

## 10. 实施计划

### Phase 1: 核心骨架

| 任务 | 产出 | 预计工作量 |
|------|------|-----------|
| 编写 SKILL.md | 完整的入口文件 | - |
| 实现 init-harness.sh | 初始化脚本 + 所有模板 | - |
| 实现 audit-harness.sh | 审计脚本 | - |
| 编写 MATURITY-MODEL.md | 成熟度模型参考 | - |

Phase 1 完成后即可使用 `/harness init` 和 `/harness audit` 两大核心功能。

### Phase 2: 深度参考

| 任务 | 产出 |
|------|------|
| 编写 ARCHITECTURE-PATTERNS.md | 架构模式参考 |
| 编写 AGENTS-MD-GUIDE.md | AGENTS.md 编写指南 |
| 编写 CONTEXT-ENGINEERING.md | 上下文工程参考 |
| 编写 TASK-SPEC-FORMAT.md | 任务格式规范 |
| 编写 PR-WORKFLOW.md | PR 工作流参考 |

### Phase 3: 高级功能

| 任务 | 产出 |
|------|------|
| 实现 lint-architecture.sh | 通用架构校验 |
| 实现 check-doc-freshness.sh | 文档新鲜度检查 |
| 编写 OBSERVABILITY.md | 可观测性参考 |
| 编写 ENTROPY-MANAGEMENT.md | 熵管理参考 |
| 编写 METRICS.md / SECURITY.md | 剩余参考文档 |
| 编写 CI 模板 | GitHub Actions + GitLab CI |

---

## 11. 开放问题

以下问题需要你的决策：

### Q1: Skill 名称
当前拟定 `harness-engineering`。是否需要更短的名称（如 `harness`）以便 slash command 更简洁？

### Q2: 配置文件位置
架构校验的配置文件放在哪里？
- 方案 A: `.harness/architecture.json`（专用目录）
- 方案 B: 直接写在 `docs/ARCHITECTURE.md` 中用特殊标记

### Q3: 多语言模板策略
对于不同技术栈（Node/Python/Go/Rust），模板的差异主要在命令部分。
- 方案 A: 一套通用模板 + 技术栈探测自动填充
- 方案 B: 每个技术栈一套独立模板

### Q4: 是否包含 "自动修复" 能力
audit 发现问题后，是否让脚本自动修复（如创建缺失的文档），还是只输出报告让 Agent 决定如何修复？
- 方案 A: 脚本只输出报告，修复由 Agent 执行（更灵活）
- 方案 B: 脚本提供 `--fix` 参数可自动修复简单问题（更高效）

### Q5: 分发和版本管理
- 是否要建立独立的 GitHub 仓库？
- 是否要提交到 skillsmp.com 等 Skill 市场？
- 版本更新策略是什么？
