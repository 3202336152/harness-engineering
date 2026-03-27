# 02 -- 架构设计

> Harness Engineering Skill | 版本 1.0

---

## 1. 总体架构

### 1.1 系统定位

```
+----------------------------------------------------+
|                  AI 编码代理                          |
|  (Claude Code / Codex / Cursor / Gemini CLI / ...)  |
+----------------------------------------------------+
        |                    |                |
        v                    v                v
  [SKILL.md 加载]    [scripts/ 执行]   [references/ 按需读取]
        |                    |                |
+----------------------------------------------------+
|           harness-engineering skill                  |
|                                                      |
|  SKILL.md -----> 核心指令 (< 500 行)                |
|  scripts/ -----> 可执行脚本 (bash)                   |
|  references/ --> 深层参考文档 (markdown)              |
|  assets/ ------> 模板和静态资源                       |
+----------------------------------------------------+
        |
        v
  [用户的项目仓库]
  - 生成 AGENTS.md / CLAUDE.md
  - 生成 docs/ 结构
  - 输出审计报告 (JSON)
```

### 1.2 分层模型

本 Skill 采用三层渐进式披露架构，与 Agent Skills 规范的推荐一致：

```
Layer 1: 元数据 (~100 tokens)
  └── SKILL.md frontmatter (name + description)
      Agent 启动时加载，用于决定是否激活此 Skill

Layer 2: 核心指令 (< 5000 tokens, 推荐)
  └── SKILL.md body (< 500 行)
      Skill 被激活后加载，包含三大命令的完整指令

Layer 3: 按需资源
  ├── scripts/    -- Agent 根据指令执行
  ├── references/ -- Agent 需要深层知识时读取
  └── assets/     -- 模板和配置文件
```

---

## 2. 目录结构（最终交付物）

### 2.1 Phase 1 交付物（标记 [P1]）

```
harness-engineering/                    # 仓库根目录 = skill 目录
│
├── SKILL.md                     [P1]   # 入口文件，YAML frontmatter + 核心指令
├── README.md                    [P1]   # GitHub 仓库说明（非 Skill 规范要求）
├── LICENSE                      [P1]   # MIT 许可证
│
├── scripts/                     [P1]
│   ├── init-harness.sh          [P1]   # 初始化 Harness 结构
│   └── audit-harness.sh         [P1]   # 审计 Harness 健康度
│
├── references/                  [P1]
│   └── MATURITY-MODEL.md        [P1]   # 成熟度模型 Level 0-4
│
├── assets/
│   └── templates/               [P1]
│       ├── AGENTS.md.tpl        [P1]   # AGENTS.md 模板
│       ├── CLAUDE.md.tpl        [P1]   # CLAUDE.md 模板
│       ├── CONVENTIONS.md.tpl   [P1]   # 编码规范模板
│       ├── ARCHITECTURE.md.tpl  [P1]   # 架构文档模板
│       ├── TESTING.md.tpl       [P1]   # 测试策略模板
│       ├── SECURITY.md.tpl      [P1]   # 安全文档模板
│       ├── PR_TEMPLATE.md.tpl   [P1]   # PR 模板
│       └── core-beliefs.md.tpl  [P1]   # 核心信念模板
│
└── tests/                       [P1]   # 测试目录
    ├── test-init.sh             [P1]   # init 脚本测试
    ├── test-audit.sh            [P1]   # audit 脚本测试
    ├── fixtures/                [P1]   # 测试用固定数据
    │   ├── empty-project/              # 空项目
    │   ├── basic-node-project/         # 基础 Node 项目
    │   ├── full-harness-project/       # 完整 Harness 项目
    │   └── partial-harness-project/    # 部分 Harness 项目
    └── run-tests.sh             [P1]   # 测试入口脚本
```

### 2.2 Phase 2-3 扩展（未来）

```
harness-engineering/
├── scripts/
│   ├── lint-architecture.sh            # Phase 3
│   └── check-doc-freshness.sh          # Phase 3
│
├── references/
│   ├── ARCHITECTURE-PATTERNS.md        # Phase 2
│   ├── AGENTS-MD-GUIDE.md              # Phase 2
│   ├── CONTEXT-ENGINEERING.md          # Phase 2
│   ├── TASK-SPEC-FORMAT.md             # Phase 2
│   ├── PR-WORKFLOW.md                  # Phase 2
│   ├── OBSERVABILITY.md                # Phase 3
│   ├── ENTROPY-MANAGEMENT.md           # Phase 3
│   ├── METRICS.md                      # Phase 3
│   └── SECURITY.md                     # Phase 3
│
└── assets/
    └── ci-templates/
        ├── github-actions.yml.tpl      # Phase 3
        └── gitlab-ci.yml.tpl           # Phase 3
```

---

## 3. 模块划分与职责

### 3.1 SKILL.md -- 指令中枢

| 段落 | 行数预算 | 职责 |
|------|----------|------|
| frontmatter | ~15 行 | 元数据：name, description, license, compatibility, metadata, allowed-tools |
| 概述 | ~20 行 | Harness Engineering 定义、核心公式、本 Skill 能力概览 |
| /harness init | ~80 行 | 初始化命令的触发条件、流程、脚本调用、输出解读 |
| /harness audit | ~80 行 | 审计命令的触发条件、维度、评分、脚本调用、报告解读 |
| /harness plan | ~60 行 | 任务规划命令的触发条件、输入输出格式 |
| 架构约束速查 | ~60 行 | 分层模型、依赖规则、指向 references/ 的链接 |
| 上下文工程速查 | ~40 行 | AGENTS.md 编写原则、分层上下文模型 |
| 熵管理速查 | ~30 行 | 黄金原则、清理策略 |
| 反模式清单 | ~30 行 | 10 个常见反模式 |
| **合计** | **~415 行** | < 500 行限制 |

### 3.2 scripts/ -- 可执行脚本

```
scripts/
├── init-harness.sh      # 入口：初始化 Harness 结构
│   ├── 检测 git 仓库
│   ├── 检测已有文件（幂等保护）
│   ├── 检测技术栈
│   ├── 从 assets/templates/ 复制并填充模板
│   ├── 创建目录结构
│   └── 输出 JSON 报告
│
└── audit-harness.sh     # 入口：审计 Harness 健康度
    ├── 8 维度独立评分
    ├── 加权计算总分
    ├── 映射成熟度等级
    ├── 生成优先级修复建议
    └── 输出 JSON 报告
```

### 3.3 references/ -- 深层参考

```
references/
└── MATURITY-MODEL.md    # Phase 1 唯一的 reference 文件
    ├── Level 0-4 完整定义
    ├── 每级检查清单
    └── 升级路径建议
```

### 3.4 assets/templates/ -- 项目模板

每个 `.tpl` 文件是可复制的 Markdown 模板，使用 `{{VARIABLE}}` 占位符。

| 模板 | 变量 | 用途 |
|------|------|------|
| AGENTS.md.tpl | PROJECT_NAME, DESCRIPTION, STACK_COMMANDS | 项目 Agent 入口 |
| CLAUDE.md.tpl | PROJECT_NAME, DESCRIPTION, STACK_COMMANDS | Claude Code 入口 |
| CONVENTIONS.md.tpl | 无变量 | 编码规范骨架 |
| ARCHITECTURE.md.tpl | PROJECT_NAME | 架构文档骨架 |
| TESTING.md.tpl | TEST_COMMAND | 测试策略骨架 |
| SECURITY.md.tpl | 无变量 | 安全文档骨架 |
| PR_TEMPLATE.md.tpl | 无变量 | GitHub PR 模板 |
| core-beliefs.md.tpl | 无变量 | 核心设计信念骨架 |

---

## 4. 数据流

### 4.1 初始化流程

```
用户/Agent: "/harness init" 或 "初始化 Harness 结构"
    │
    v
SKILL.md: 解析触发条件，指导 Agent 执行
    │
    v
Agent: 调用 scripts/init-harness.sh [--project-name X] [--dry-run] [--force]
    │
    v
init-harness.sh:
    ├── 1. 检测 .git/ 是否存在
    ├── 2. 检测 AGENTS.md / CLAUDE.md 是否已存在
    ├── 3. 检测技术栈 (package.json / pyproject.toml / go.mod / Cargo.toml)
    ├── 4. 读取 assets/templates/*.tpl
    ├── 5. 替换 {{VARIABLE}} 占位符
    ├── 6. 写入目标文件（幂等：已有则跳过）
    ├── 7. 创建 docs/ 目录结构
    └── 8. 输出 JSON 报告 --> stdout
    │
    v
Agent: 解析 JSON，向用户展示结果和 next_steps
```

### 4.2 审计流程

```
用户/Agent: "/harness audit" 或 "检查 Harness 状态"
    │
    v
SKILL.md: 解析触发条件，指导 Agent 执行
    │
    v
Agent: 调用 scripts/audit-harness.sh [--json]
    │
    v
audit-harness.sh:
    ├── 维度 1: 入口文档检查 (15%)
    ├── 维度 2: 文档结构检查 (15%)
    ├── 维度 3: 文档新鲜度检查 (10%)
    ├── 维度 4: 架构约束检查 (15%)
    ├── 维度 5: 测试覆盖检查 (15%)
    ├── 维度 6: 自动化检查 (10%)
    ├── 维度 7: 执行计划检查 (10%)
    ├── 维度 8: 安全治理检查 (10%)
    ├── 计算加权总分
    ├── 映射成熟度等级 (L0-L4)
    ├── 生成优先级修复列表
    └── 输出 JSON 报告 --> stdout
    │
    v
Agent: 解析 JSON，展示评分、等级和修复建议
```

### 4.3 任务规划流程

```
用户: "/harness plan 添加用户搜索功能"
    │
    v
SKILL.md: 指导 Agent 执行规划流程
    │
    v
Agent:
    ├── 1. 读取 references/TASK-SPEC-FORMAT.md (Phase 2，暂内联在 SKILL.md)
    ├── 2. 读取项目的 docs/ARCHITECTURE.md
    ├── 3. 生成 "目标+约束+验收标准" 格式的执行计划
    ├── 4. 写入 docs/exec-plans/active/<plan-name>.md
    └── 5. 展示计划供用户审核
```

---

## 5. skills.sh 适配架构

### 5.1 仓库结构映射

Agent Skills 规范要求 skill 目录名 = name 字段值。我们的仓库结构：

```
GitHub 仓库: <owner>/harness-engineering
    │
    └── harness-engineering/     # <-- 这个目录是 skill 根目录
        ├── SKILL.md             #     name: harness-engineering
        ├── scripts/
        ├── references/
        └── assets/
```

**关键决策**: 仓库根目录直接作为 skill 目录。即：

```
仓库根目录 = skill 目录 = harness-engineering/
```

这样 `npx skills add <owner>/harness-engineering` 会将整个仓库克隆到 Agent 的 skills 目录中。

### 5.2 安装路径映射

| Agent | 安装路径 | 安装方式 |
|-------|----------|----------|
| Claude Code | `~/.claude/skills/harness-engineering/` | `npx skills add <owner>/harness-engineering` |
| Codex | `~/.codex/skills/harness-engineering/` | `npx skills add -a codex <owner>/harness-engineering` |
| Cursor | `~/.cursor/skills/harness-engineering/` | `npx skills add -a cursor <owner>/harness-engineering` |
| 通用 | 项目级 `.skills/harness-engineering/` | `npx skills add --project <owner>/harness-engineering` |

### 5.3 脚本路径解析

脚本内部需要知道自身所在的 skill 目录，以便引用 assets/templates/：

```bash
# 在 init-harness.sh 中
SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATES_DIR="$SKILL_DIR/assets/templates"
```

这确保无论 Skill 安装在哪个路径，脚本都能正确定位模板文件。

---

## 6. 接口定义

### 6.1 init-harness.sh 接口

```
输入:
  --project-name <string>   # 可选，默认取 basename of pwd
  --description <string>    # 可选，默认 ""
  --force                   # 可选，覆盖已有文件
  --dry-run                 # 可选，仅打印操作

输出 (stdout, JSON):
  {
    "status": "success" | "error",
    "project": "<string>",
    "created_files": ["<string>", ...],
    "created_dirs": ["<string>", ...],
    "skipped_files": ["<string>", ...],
    "detected_stack": "node" | "python" | "go" | "rust" | "unknown",
    "next_steps": ["<string>", ...],
    "error"?: "<string>"
  }

退出码:
  0 = 成功
  1 = 错误（非 git 仓库等）
```

### 6.2 audit-harness.sh 接口

```
输入:
  --json                    # 可选（默认即 JSON 输出）
  --verbose                 # 可选，包含详细检查项

输出 (stdout, JSON):
  {
    "status": "completed",
    "overall_score": <0-100>,
    "maturity_level": <0-4>,
    "maturity_label": "<string>",
    "dimensions": {
      "<dimension_id>": {
        "score": <0-100>,
        "weight": <float>,
        "status": "<string>",
        "details": ["<string>", ...],
        "fix": "<string>"
      },
      ...
    },
    "priority_fixes": [
      {
        "priority": <int>,
        "dimension": "<string>",
        "action": "<string>",
        "impact": "high" | "medium" | "low"
      },
      ...
    ]
  }

退出码:
  0 = 审计完成（无论分数高低）
  1 = 审计过程出错
```

---

## 7. 设计决策记录

| 决策 | 选项 | 选择 | 理由 |
|------|------|------|------|
| 仓库根 vs 子目录 | A: 仓库根=skill根 / B: 仓库内子目录 | A | skills CLI 默认将仓库根作为 skill 目录 |
| 脚本语言 | bash / python / node | bash | 零依赖，所有平台预装 |
| 输出格式 | JSON / YAML / 纯文本 | JSON | Agent 最易解析，jq 通用 |
| 模板引擎 | sed 替换 / envsubst / 自定义 | sed 替换 | 零依赖，简单可靠 |
| 审计结果存储 | stdout / 文件 / 两者 | stdout | Agent 直接读取，不产生临时文件 |
| 技术栈检测方式 | 文件存在性 / 文件内容解析 | 文件存在性 | 简单可靠，覆盖 80% 场景 |
