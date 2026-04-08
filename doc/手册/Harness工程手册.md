# Harness Engineering 工程手册

> 版本: 1.0 | 日期: 2026-03-27
> 适用工具: OpenAI Codex / Claude Code / Cursor / Windsurf / 任何支持 AGENTS.md 或 CLAUDE.md 的 AI IDE
> 来源: OpenAI Harness Engineering (2026.02), Martin Fowler, HumanLayer, NxCode, 社区实践

> 说明：这是一份方法论和实践手册，适合了解 Harness Engineering 的完整思路。
> 如果你想找“具体命令怎么用、项目里到底会生成什么、模板怎么改”，不要从这份手册开始，优先看 [../本地使用指南.md](../本地使用指南.md)。
> 它不是当前仓库实现的逐条契约；当前行为请优先参考 [../../SKILL.md](../../SKILL.md) 和 [../本地使用指南.md](../本地使用指南.md)。
> 当前实现补充：`doc/` 下维护文档使用中文文件名；项目级共享规范位于 `docs/project/`，功能级规范位于 `docs/features/`，模板默认生成中文内容。

---

## 第零章: 什么是 Harness Engineering

### 定义

Harness Engineering 是设计 **环境、约束和反馈循环** 使 AI 编码代理能够可靠地大规模运作的工程学科。

类比: 马匹（AI 模型）强大但无方向感。马具（Harness）是缰绳、鞍具、嚼子 -- 引导力量走向正确方向。骑手（人类工程师）不再亲自跑，而是设计系统、表达意图、提供反馈。

### 核心公式

```
编码代理 = AI 模型 + Harness
```

模型正在商品化。Harness 才是真正的竞争壁垒。LangChain 仅通过优化 Harness（加入自验证循环和死循环检测），在不换模型的情况下将 Terminal Bench 2.0 排名从 Top 30 提升到 Top 5。

### 三个时代的演进

| 时代 | 年份 | 类比 | 核心关注 |
|------|------|------|----------|
| Prompt Engineering | 2023-2024 | 写好一封邮件 | 单次指令优化 |
| Context Engineering | 2025 | 给邮件附上所有正确的附件 | 动态上下文窗口构建 |
| Harness Engineering | 2026 | 设计整个办公室 | 工作流、约束、反馈循环、生命周期 |

---

## 第一章: 项目结构规范

### 1.1 目录结构（必须遵循）

```
project-root/
├── AGENTS.md                    # 入口文件，~100行，仅作索引
├── CLAUDE.md                    # Claude Code 专用（内容可与 AGENTS.md 同步）
├── .cursorrules                 # Cursor 专用（内容可与 AGENTS.md 同步）
├── docs/
│   ├── ARCHITECTURE.md          # 顶层架构图和领域划分
│   ├── CONVENTIONS.md           # 代码规范、命名约定、风格指南
│   ├── SECURITY.md              # 安全约束、认证流程、敏感数据处理
│   ├── TESTING.md               # 测试策略、覆盖率要求、测试命令
│   ├── RELIABILITY.md           # 可靠性标准、失败模式、SLA
│   ├── FRONTEND.md              # 前端架构和组件规范（如适用）
│   ├── BACKEND.md               # 后端架构和 API 规范（如适用）
│   ├── design-docs/             # 已验证的架构决策文档
│   │   ├── core-beliefs.md      # 核心设计信念（不可轻易变更）
│   │   ├── auth-system.md       # 认证系统设计
│   │   └── data-model.md        # 数据模型设计
│   ├── exec-plans/              # 执行计划（一等公民）
│   │   ├── active/              # 当前进行中的计划
│   │   ├── completed/           # 已完成的计划
│   │   └── tech-debt/           # 技术债务计划
│   ├── product-specs/           # 产品需求和用户流程
│   ├── references/              # 外部库文档（重格式化为 LLM 友好格式）
│   └── generated/               # 自动生成的文档（如数据库 schema）
├── scripts/
│   ├── lint-architecture.sh     # 架构约束校验脚本
│   ├── check-doc-freshness.sh   # 文档新鲜度检查
│   └── validate-boundaries.sh   # 依赖边界验证
├── .github/
│   └── PULL_REQUEST_TEMPLATE.md
├── src/
└── tests/
```

### 1.2 AGENTS.md 标准模板

```markdown
# [项目名称]

[一句话描述项目用途和技术栈]

## 快速命令

```bash
npm install          # 安装依赖
npm run dev          # 启动开发服务器
npm test             # 运行测试
npm run lint         # 代码检查
npm run typecheck    # 类型检查
npm run build        # 构建项目
```

## 架构概述

[2-3句话描述核心架构模式]

详细架构: docs/ARCHITECTURE.md

### 分层模型

每个业务领域遵循严格的分层依赖:

```
Types -> Config -> Repo -> Service -> Runtime -> UI
```

依赖只能从左到右流动。跨切面关注点通过 Providers 注入。
违反此规则的代码将被 CI 拒绝。

## 关键约束

1. 修改核心基础设施前必须审查 docs/design-docs/core-beliefs.md
2. 所有变更必须通过 docs/TESTING.md 中定义的自动化验收场景
3. 合并 PR 前必须更新 docs/ 中的相关文档
4. 数据在系统边界处验证，内部代码互相信任
5. 优先使用共享工具包，避免重复造轮子

## 文档导航

| 主题 | 文件 | 用途 |
|------|------|------|
| 架构 | docs/ARCHITECTURE.md | 领域划分和包层次 |
| 规范 | docs/CONVENTIONS.md | 命名、格式、代码风格 |
| 安全 | docs/SECURITY.md | 认证、权限、敏感数据 |
| 测试 | docs/TESTING.md | 测试策略和命令 |
| 设计决策 | docs/design-docs/ | 已验证的架构决策 |
| 执行计划 | docs/exec-plans/ | 当前和已完成的计划 |
| 产品需求 | docs/product-specs/ | 功能需求和用户流程 |

## Git 工作流

- 分支命名: `feat/xxx`, `fix/xxx`, `refactor/xxx`
- Commit 格式: `type(scope): description`
- PR 必须包含测试用例
- 每个 PR 聚焦单一职责，保持小而频繁
```

---

## 第二章: 架构约束的机械化执行

### 2.1 核心原则

**不要靠文档约束行为，要用代码强制执行。** Agent 不会"遵守"文档中的建议，但会被 CI 失败阻止。

### 2.2 分层架构模型

```
Domain: [user | payment | order | ...]
  │
  ├── types/       # 纯类型定义，零依赖
  ├── config/      # 配置读取，仅依赖 types
  ├── repo/        # 数据访问层，依赖 types + config
  ├── service/     # 业务逻辑，依赖 types + config + repo
  ├── runtime/     # 运行时初始化，依赖上述所有
  └── ui/          # 用户界面，依赖上述所有
```

**依赖规则（必须机械化执行）:**
- 依赖只能从左到右（从上到下）
- 同层之间禁止互相依赖
- 跨领域（cross-domain）依赖仅通过 Providers 接口
- 违规时 CI 报错并附带修复指引

### 2.3 自定义 Linter 示例

创建 `scripts/lint-architecture.sh`:

```bash
#!/bin/bash
# 架构边界校验脚本
# 在 CI 和 pre-commit hook 中运行

set -euo pipefail

ERRORS=0

# 检查 types/ 不应导入其他层
echo "Checking types/ layer boundaries..."
if grep -rn "from.*\.\./\(config\|repo\|service\|runtime\|ui\)" src/*/types/ 2>/dev/null; then
  echo "ERROR: types/ layer must not import from other layers."
  echo "FIX: Move shared types to the types/ layer or use dependency injection."
  ERRORS=$((ERRORS + 1))
fi

# 检查 repo/ 不应导入 service/ 或更高层
echo "Checking repo/ layer boundaries..."
if grep -rn "from.*\.\./\(service\|runtime\|ui\)" src/*/repo/ 2>/dev/null; then
  echo "ERROR: repo/ layer must not import from service/, runtime/, or ui/."
  echo "FIX: Invert the dependency using interfaces defined in types/."
  ERRORS=$((ERRORS + 1))
fi

# 检查跨域直接导入
echo "Checking cross-domain boundaries..."
for domain_dir in src/*/; do
  domain=$(basename "$domain_dir")
  if grep -rn "from.*src/\($(ls src/ | grep -v "$domain" | tr '\n' '|' | sed 's/|$//')\)/" "$domain_dir" 2>/dev/null | grep -v "providers/" ; then
    echo "ERROR: Direct cross-domain import detected in $domain."
    echo "FIX: Use Providers interface for cross-domain communication."
    ERRORS=$((ERRORS + 1))
  fi
done

if [ $ERRORS -gt 0 ]; then
  echo ""
  echo "Found $ERRORS architecture boundary violation(s)."
  echo "See docs/ARCHITECTURE.md for the layered dependency model."
  exit 1
fi

echo "Architecture boundary check passed."
```

### 2.4 CI 集成

```yaml
# .github/workflows/harness.yml
name: Harness Validation

on: [push, pull_request]

jobs:
  architecture:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Check architecture boundaries
        run: bash scripts/lint-architecture.sh

      - name: Check naming conventions
        run: |
          # 文件命名: kebab-case
          find src/ -name "*.ts" -o -name "*.tsx" | while read f; do
            base=$(basename "$f" | sed 's/\.\(ts\|tsx\)$//')
            if ! echo "$base" | grep -qE '^[a-z][a-z0-9]*(-[a-z0-9]+)*$'; then
              # 允许 index 文件和类型定义
              if [ "$base" != "index" ] && ! echo "$base" | grep -qE '\.d$'; then
                echo "ERROR: File '$f' does not follow kebab-case naming."
                exit 1
              fi
            fi
          done

      - name: Check documentation freshness
        run: bash scripts/check-doc-freshness.sh

  tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
      - run: npm ci
      - run: npm run typecheck
      - run: npm test -- --json --outputFile=test-results.json
      - run: npm run lint
```

### 2.5 错误消息必须包含修复指引

这是关键实践。当 Agent 违反约束时，错误消息本身就是修复指南:

```
ERROR: types/ layer must not import from service/.
  Violation: src/user/types/user-dto.ts imports from src/user/service/user-service.ts

FIX: Move the shared interface to src/user/types/ and have both layers reference it.
See: docs/ARCHITECTURE.md#layered-model for the dependency flow diagram.
```

Agent 读到这个错误后可以自行修复，无需人工干预。

---

## 第三章: 上下文工程（Context Engineering）

### 3.1 上下文预算原则

AGENTS.md 中的每一个 token 都在与任务本身争夺注意力。遵循以下原则:

| 原则 | 说明 |
|------|------|
| 渐进式披露 | 入口文件只放索引，深层内容按需加载 |
| 100 行上限 | AGENTS.md 不超过 100 行 |
| 仓库即真理 | 知识不在仓库里 = 对 Agent 不存在 |
| 去除冗余 | 自动生成的 AGENTS.md 反而降低 20%+ 性能 |
| 分层上下文 | Tier 1（自动加载）-> Tier 2（按需加载）-> Tier 3（磁盘待命）|

### 3.2 知识迁移清单

所有影响 Agent 行为的知识必须从以下位置迁移到仓库:

- [ ] Slack/飞书消息中的架构决策 -> `docs/design-docs/`
- [ ] Google Docs/Notion 中的产品需求 -> `docs/product-specs/`
- [ ] 团队成员脑中的隐性知识 -> `docs/CONVENTIONS.md`
- [ ] 外部库文档 -> `docs/references/`（重格式化为 LLM 友好格式）
- [ ] 会议纪要中的决策 -> `docs/design-docs/`
- [ ] CI/CD 配置的理由 -> `docs/ARCHITECTURE.md`

### 3.3 分层上下文模型

```
Tier 1 - 自动加载（每次会话）
├── AGENTS.md / CLAUDE.md（索引，<100行）
└── 当前任务上下文

Tier 2 - 按需加载（触发时）
├── Skills / SKILL.md（特定能力的指令包）
├── Sub-agent 研究结果
└── 特定领域文档

Tier 3 - 磁盘待命（Agent 主动检索）
├── docs/ 全部内容
├── 代码库本身
└── 测试结果和日志
```

---

## 第四章: 可观测性与反馈循环

### 4.1 为什么需要可观测性

OpenAI 团队发现: 当代码吞吐量提升后，瓶颈转移到人类 QA 能力。解决方案是让应用本身对 Agent 可读，Agent 自己做 QA。

### 4.2 三大集成能力

#### 4.2.1 可引导的工作树（Bootable Worktrees）

每个任务在隔离的 git worktree 中运行，互不干扰:

```bash
# 创建隔离工作树
git worktree add .worktrees/task-123 -b task-123

# Agent 在工作树中启动独立的应用实例
cd .worktrees/task-123
npm install && npm run dev -- --port 0  # 随机端口，避免冲突

# 任务完成后清理
git worktree remove .worktrees/task-123
```

**要求:** 应用必须支持一键启动（`npm run dev` 或等效命令），不依赖外部状态。

#### 4.2.2 浏览器自动化（Chrome DevTools Protocol）

Agent 可以直接操作浏览器验证 UI 行为:

```javascript
// Agent 可执行的验证操作
const capabilities = {
  // DOM 快照 - 获取页面结构
  getDOM: () => page.content(),

  // 截图 - 视觉验证
  screenshot: () => page.screenshot({ path: 'evidence.png' }),

  // 导航 - 模拟用户操作
  navigate: (url) => page.goto(url),

  // 交互 - 点击、输入、滚动
  interact: async () => {
    await page.click('#submit-btn');
    await page.waitForSelector('.success-message');
  },

  // 断言 - 验证结果
  verify: async () => {
    const text = await page.textContent('.result');
    return text === 'Expected output';
  }
};
```

#### 4.2.3 本地可观测性栈

Agent 可以查询日志和指标来验证约束:

```bash
# 结构化日志（Agent 可解析）
# 应用日志格式要求:
{"timestamp":"2026-03-27T10:00:00Z","level":"info","component":"auth","action":"login","userId":"123","duration_ms":45}

# Agent 验证性能约束的方式:
# "服务启动必须在 800ms 内完成"
cat logs/startup.json | jq '.duration_ms' # 如果 > 800，Agent 自行优化

# "API 响应时间必须 < 200ms"
cat logs/api.json | jq 'select(.duration_ms > 200)' # 找出慢请求并优化
```

### 4.3 结构化测试输出

测试结果必须是机器可读的:

```json
// package.json
{
  "scripts": {
    "test": "jest",
    "test:json": "jest --json --outputFile=test-results.json",
    "test:coverage": "jest --coverage --json --outputFile=coverage-results.json"
  }
}
```

**反馈原则:**
- 成功时保持沉默（不要用通过的测试输出污染上下文）
- 失败时提供详细信息（错误消息 + 堆栈 + 修复建议）
- 覆盖率下降时自动提醒 Agent 补充测试

---

## 第五章: 熵管理（Entropy Management）

### 5.1 问题定义

AI 生成的代码会以不同于人类代码的方式积累"技术债":
- 文档与代码不同步（文档漂移）
- 死代码和未使用的导入
- 命名不一致
- 重复逻辑（Agent 倾向于复制而非抽象）
- 过度工程化（不必要的抽象层）

### 5.2 黄金原则（编入仓库，机械执行）

在 `docs/CONVENTIONS.md` 中定义并在 CI 中强制执行:

```markdown
## 黄金原则

1. 优先使用共享工具包（`src/shared/`），禁止在业务代码中重复实现
2. 数据在系统边界处验证，内部方法之间互相信任
3. 使用团队的标准并发工具，禁止自行实现锁/队列
4. 单个文件不超过 300 行；单个函数不超过 50 行
5. 每个公开 API 必须有对应的集成测试
6. 日志必须使用结构化格式，禁止 console.log 裸输出
```

### 5.3 自动清理代理（Garbage Collection）

定期运行清理任务:

```markdown
## 熵管理计划任务

### 每日任务
- 运行 linter 检查架构边界违规
- 检查测试覆盖率是否下降

### 每周任务
- 文档新鲜度扫描（docs/ 中超过 30 天未更新的文件）
- 死代码检测（未使用的导出、未引用的文件）
- 依赖审计（未使用的 npm 包）

### 每月任务
- 全面架构一致性审查
- 技术债务盘点和优先级排序
- AGENTS.md 和 docs/ 全面审查
```

实现文档新鲜度检查:

```bash
#!/bin/bash
# scripts/check-doc-freshness.sh
# 检查 docs/ 中的文件是否与相关代码同步

STALE_DAYS=30
WARNINGS=0

echo "Checking documentation freshness..."

for doc in docs/*.md docs/**/*.md; do
  [ -f "$doc" ] || continue

  last_modified=$(git log -1 --format="%ct" -- "$doc" 2>/dev/null || echo 0)
  now=$(date +%s)
  age_days=$(( (now - last_modified) / 86400 ))

  if [ "$age_days" -gt "$STALE_DAYS" ]; then
    echo "WARNING: $doc has not been updated in $age_days days."
    echo "  Last modified: $(git log -1 --format='%ci' -- "$doc")"
    WARNINGS=$((WARNINGS + 1))
  fi
done

if [ "$WARNINGS" -gt 0 ]; then
  echo ""
  echo "Found $WARNINGS stale document(s). Consider updating or archiving."
  echo "Run: 'git log --oneline -- docs/' to see recent doc changes."
  # 警告但不阻塞（exit 0），除非团队决定强制
  exit 0
fi

echo "All documentation is fresh."
```

---

## 第六章: 任务指令规范

### 6.1 指令结构（目标 + 约束 + 验收标准）

每个交给 Agent 的任务必须包含三个部分:

```markdown
## 任务: [简短标题]

### 目标
[明确描述要实现什么，用用户故事或功能描述]

### 约束
- 遵循 docs/ARCHITECTURE.md 的分层模型
- 不修改 src/shared/ 中的公共接口
- 使用现有的 [具体组件/工具] 而非新建
- 性能要求: [具体数字]

### 验收标准
- [ ] `npm test` 全部通过
- [ ] `npm run typecheck` 无错误
- [ ] `npm run lint` 无警告
- [ ] 新增功能有对应的单元测试（覆盖率 > 80%）
- [ ] 更新了 docs/ 中的相关文档
- [ ] [具体的功能验证步骤]
```

### 6.2 执行计划作为一等公民

复杂任务在执行前必须先生成计划，并签入仓库:

```markdown
<!-- docs/exec-plans/active/add-search-feature.md -->

# 执行计划: 用户搜索功能

## 状态: 进行中
## 创建日期: 2026-03-27
## 负责 Agent: codex-session-abc123

## 目标
在 /users 页面添加实时搜索功能

## 步骤

### Phase 1: 数据层 [已完成]
- [x] 在 src/user/repo/ 添加搜索查询方法
- [x] 添加数据层单元测试

### Phase 2: 服务层 [进行中]
- [x] 在 src/user/service/ 添加搜索业务逻辑
- [ ] 添加 debounce 处理（300ms）
- [ ] 添加服务层测试

### Phase 3: UI 层 [待开始]
- [ ] 创建 SearchInput 组件
- [ ] 集成到 UserList 页面
- [ ] 添加空结果状态显示
- [ ] 添加 E2E 测试

## 决策日志
- 2026-03-27: 选择前端 debounce 而非后端节流，原因: 减少网络请求
- 2026-03-27: 搜索字段确定为用户名和邮箱，排除手机号（产品决策）

## 遇到的问题
- [无]
```

---

## 第七章: PR 工作流

### 7.1 PR 模板

```markdown
<!-- .github/PULL_REQUEST_TEMPLATE.md -->

## 变更内容
[一句话描述这个 PR 做了什么]

## 变更原因
[为什么需要这个变更，关联的 issue 或计划]

## 变更类型
- [ ] 新功能
- [ ] Bug 修复
- [ ] 重构
- [ ] 文档更新
- [ ] 测试补充

## 验证清单
- [ ] `npm test` 通过
- [ ] `npm run typecheck` 通过
- [ ] `npm run lint` 通过
- [ ] 架构边界检查通过
- [ ] 包含对应测试用例
- [ ] 文档已更新（如需要）

## 证据
[截图、测试输出、或性能对比数据]
```

### 7.2 合并哲学（Agent-First 模式）

| 传统模式 | Agent-First 模式 |
|----------|-----------------|
| 最小化 PR，避免风险 | 高频小 PR，修正比等待便宜 |
| 长审查队列 | 短生命周期分支 |
| 测试 flake 阻塞流程 | flake 通过重跑解决 |
| 等待 = 谨慎 | 等待 = 浪费；回滚 = 快速 |

**目标吞吐量: 3.5 PR/工程师/天**

人类的角色从逐行审代码转变为:
1. 验证意图是否正确（PR 做的是不是我要的）
2. 检查架构决策是否合理
3. 发现"AI slop"（不必要的复杂度、重复代码、过度工程）

---

## 第八章: Sub-Agent 策略（上下文防火墙）

### 8.1 为什么需要 Sub-Agent

长任务（6小时+）中，主 Agent 的上下文窗口会被中间噪声污染。Sub-Agent 充当"上下文防火墙":

```
主 Agent（编排者）
├── Sub-Agent A: 代码库研究（只返回摘要 + 文件路径:行号）
├── Sub-Agent B: 实现功能模块 1
├── Sub-Agent C: 实现功能模块 2
└── Sub-Agent D: 编写测试
```

**主 Agent 只看到:**
- 发送给 Sub-Agent 的提示
- Sub-Agent 返回的最终结果

不看到 Sub-Agent 的中间搜索、文件读取、试错过程。

### 8.2 模型分配策略

| 角色 | 推荐模型 | 原因 |
|------|----------|------|
| 主 Agent（编排） | Opus / GPT-5 | 需要强推理和全局视野 |
| 研究 Sub-Agent | Sonnet / GPT-4.1 | 搜索和总结不需要最强推理 |
| 实现 Sub-Agent | Sonnet / GPT-4.1 | 代码生成性价比高 |
| 简单任务 Sub-Agent | Haiku / GPT-4.1-mini | 格式化、重命名等 |

### 8.3 Sub-Agent 指令模板

```markdown
## 研究任务

在代码库中找到所有与用户认证相关的文件和函数。

返回格式:
- 每个相关文件的路径和用途（一句话）
- 关键函数列表（filepath:line_number 格式）
- 认证流程的简要描述（<200字）

不要修改任何文件。只做研究和报告。
```

---

## 第九章: 安全与治理

### 9.1 最小权限原则

```yaml
# Agent 权限矩阵
permissions:
  read:
    - src/**
    - docs/**
    - tests/**
    - package.json

  write:
    - src/**
    - tests/**
    - docs/exec-plans/**

  execute:
    - npm test
    - npm run lint
    - npm run typecheck
    - npm run build
    - scripts/*.sh

  forbidden:
    - .env*
    - credentials.*
    - npm publish
    - git push --force
    - rm -rf
    - 任何生产环境操作
```

### 9.2 审计追踪

所有 Agent 操作必须可追溯:
- Git commit 记录每次代码变更
- 执行计划记录决策过程
- CI 日志记录验证结果
- PR 评论记录人类反馈

### 9.3 快速回滚

```bash
# 每个 Agent PR 必须可以独立回滚
git revert <commit-hash>  # 单 PR 回滚

# 回滚必须在 5 分钟内完成
# 部署流水线必须支持一键回滚
```

---

## 第十章: 度量体系

### 10.1 核心指标

| 类别 | 指标 | 目标 |
|------|------|------|
| **吞吐量** | PR 数/工程师/天 | >= 3.5 |
| **吞吐量** | 首个 PR 用时 | < 2 小时 |
| **吞吐量** | 每任务迭代次数 | < 3 |
| **质量** | CI 一次通过率 | > 85% |
| **质量** | 缺陷逃逸率 | < 5% |
| **质量** | 回滚频率 | < 2%/周 |
| **人工注意力** | 审查时间/PR | < 10 分钟 |
| **人工注意力** | 升级次数/天 | < 2 |
| **Harness 健康** | 文档过期违规 | 0 |
| **Harness 健康** | 架构边界违规 | 0（CI 拦截） |
| **Harness 健康** | 测试 flake 率 | < 1% |
| **安全** | 权限拒绝事件 | 记录并审查 |

### 10.2 指标对 Agent 可见

Agent 应该能查询自身的性能指标:

```bash
# Agent 可执行的自检命令
npm test -- --json | jq '.numPassedTests, .numFailedTests'
npm run coverage -- --json | jq '.total.lines.pct'
```

---

## 第十一章: 分阶段实施路线图

### Phase 1: 基础 Harness（1-2 小时）

**立即可做:**

- [ ] 创建 `AGENTS.md`（使用本文档模板，<100行）
- [ ] 创建 `docs/ARCHITECTURE.md`（描述当前架构）
- [ ] 创建 `docs/CONVENTIONS.md`（编码规范）
- [ ] 确保 `npm test` / `npm run lint` / `npm run typecheck` 可用
- [ ] 配置 pre-commit hook（lint + format）
- [ ] 创建 PR 模板

**效果:** Agent 可以理解项目结构，生成的代码基本符合规范。

### Phase 2: 团队 Harness（1-2 天）

**短期建设:**

- [ ] 识别 3-5 个最重要的架构约束
- [ ] 将约束编码为 linter 规则或 CI 检查
- [ ] 错误消息附带修复指引
- [ ] 将团队知识从 Slack/Docs 迁移到仓库
- [ ] 建立结构化日志格式
- [ ] 创建 `docs/design-docs/core-beliefs.md`
- [ ] 配置 CI 流水线运行所有 Harness 检查

**效果:** Agent 的架构违规被自动拦截，代码一致性显著提升。

### Phase 3: 生产 Harness（1-2 周）

**中期完善:**

- [ ] 实现 per-worktree 隔离环境
- [ ] 集成浏览器自动化（Playwright/Puppeteer）
- [ ] 建立本地可观测性栈（结构化日志 + 指标查询）
- [ ] 配置自动化文档新鲜度检查
- [ ] 实现熵管理的定期清理任务
- [ ] 建立度量体系并使指标对 Agent 可见
- [ ] 设计 Sub-Agent 编排策略
- [ ] 实现快速回滚机制

**效果:** Agent 可以端到端自主工作（发现 bug -> 复现 -> 修复 -> 验证 -> 提 PR），人类只需审核意图。

---

## 第十二章: 工具适配指南

### 12.1 Claude Code

```bash
# 入口文件
CLAUDE.md          # Claude Code 优先读取此文件

# 配置 hooks（settings.json）
{
  "hooks": {
    "postSave": "npm run lint --fix",
    "preCommit": "npm test && npm run typecheck"
  }
}

# Sub-Agent 使用
# Claude Code 原生支持 Agent tool，直接在 CLAUDE.md 中指定策略
```

### 12.2 OpenAI Codex

```bash
# 入口文件
AGENTS.md          # Codex 优先读取此文件

# 全局配置
~/.codex/AGENTS.md                  # 全局默认偏好
project-root/AGENTS.md              # 项目级指令
project-root/src/api/AGENTS.md      # 子目录覆盖

# 配置
~/.codex/config.toml
  project_doc_max_bytes = 65536     # 上下文预算
```

### 12.3 Cursor

```bash
# 入口文件
.cursorrules       # Cursor 优先读取此文件

# 内容与 AGENTS.md 保持同步
# Cursor 的 @docs 功能可以引用 docs/ 目录
```

### 12.4 通用策略

无论使用哪个工具，核心实践不变:
1. 仓库根目录放入口索引文件
2. `docs/` 目录放详细文档
3. CI 中放机械化约束检查
4. 测试输出要机器可读
5. 错误消息要包含修复指引

---

## 第十三章: 反模式清单（避免踩坑）

| 反模式 | 正确做法 |
|--------|----------|
| 把所有指令塞进一个巨大的 AGENTS.md | 100行索引 + docs/ 深层文档 |
| 只用文档约束行为 | 文档 + 机械化 CI 执行 |
| "以防万一"装大量插件/Skills | 遇到具体失败再添加 |
| 一次性跑完整测试套件（5分钟+） | 子集测试 + 完整测试在 CI 跑 |
| 预先设计"完美" Harness | 从失败中迭代，每次失败编码一条规则 |
| 自动生成 AGENTS.md | 手动维护，自动生成的降低 20%+ 性能 |
| 让 Agent 无限制访问外部服务 | 最小权限 + 网络白名单 |
| 等待 = 谨慎 | 快速合并 + 快速回滚 |
| 逐行审查 Agent 代码 | 审查意图 + 架构决策 + 检测 AI slop |
| 忽略熵积累 | 每周运行清理 Agent |

---

## 附录 A: 快速启动脚本

将以下脚本保存为 `scripts/init-harness.sh`，一键初始化 Harness 结构:

```bash
#!/bin/bash
# Harness Engineering 初始化脚本
set -euo pipefail

echo "Initializing Harness Engineering structure..."

# 创建文档目录
mkdir -p docs/{design-docs,exec-plans/{active,completed,tech-debt},product-specs,references,generated}
mkdir -p scripts

# 创建 AGENTS.md 骨架
if [ ! -f AGENTS.md ]; then
cat > AGENTS.md << 'AGENTSEOF'
# [项目名称]

[一句话项目描述]

## 快速命令

```bash
npm install          # 安装依赖
npm run dev          # 启动开发服务器
npm test             # 运行测试
npm run lint         # 代码检查
npm run typecheck    # 类型检查
```

## 架构概述

[描述核心架构]

详细文档: docs/ARCHITECTURE.md

## 关键约束

1. [约束1]
2. [约束2]
3. [约束3]

## 文档导航

- 架构: docs/ARCHITECTURE.md
- 规范: docs/CONVENTIONS.md
- 测试: docs/TESTING.md
- 安全: docs/SECURITY.md
- 设计决策: docs/design-docs/
AGENTSEOF
echo "Created AGENTS.md"
fi

# 同步到其他工具的入口文件
if [ ! -f CLAUDE.md ]; then
  cp AGENTS.md CLAUDE.md
  echo "Created CLAUDE.md (synced from AGENTS.md)"
fi

if [ ! -f .cursorrules ]; then
  cp AGENTS.md .cursorrules
  echo "Created .cursorrules (synced from AGENTS.md)"
fi

# 创建文档骨架
for doc in ARCHITECTURE CONVENTIONS TESTING SECURITY; do
  if [ ! -f "docs/$doc.md" ]; then
    echo "# $doc" > "docs/$doc.md"
    echo "" >> "docs/$doc.md"
    echo "TODO: Fill in $doc documentation." >> "docs/$doc.md"
    echo "Created docs/$doc.md"
  fi
done

# 创建核心信念文档
if [ ! -f docs/design-docs/core-beliefs.md ]; then
cat > docs/design-docs/core-beliefs.md << 'EOF'
# Core Beliefs

These are fundamental design decisions that should not be changed without team consensus.

## Architecture
- [Document your core architectural decisions here]

## Technology Choices
- [Document your technology stack decisions here]

## Quality Standards
- [Document your quality requirements here]
EOF
echo "Created docs/design-docs/core-beliefs.md"
fi

# 创建 PR 模板
mkdir -p .github
if [ ! -f .github/PULL_REQUEST_TEMPLATE.md ]; then
cat > .github/PULL_REQUEST_TEMPLATE.md << 'EOF'
## What
[One sentence describing the change]

## Why
[Motivation and linked issue/plan]

## Checklist
- [ ] Tests pass (`npm test`)
- [ ] Type check passes (`npm run typecheck`)
- [ ] Lint passes (`npm run lint`)
- [ ] Includes test cases
- [ ] Documentation updated (if needed)
EOF
echo "Created .github/PULL_REQUEST_TEMPLATE.md"
fi

echo ""
echo "Harness structure initialized."
echo ""
echo "Next steps:"
echo "  1. Edit AGENTS.md with your project-specific information"
echo "  2. Fill in docs/ARCHITECTURE.md with your system design"
echo "  3. Fill in docs/CONVENTIONS.md with your coding standards"
echo "  4. Add architecture linting to your CI pipeline"
echo "  5. Keep CLAUDE.md and .cursorrules synced with AGENTS.md"
```

---

## 附录 B: Harness 成熟度自评

对照以下清单评估你的 Harness 成熟度:

```
Level 0 - 无 Harness
[ ] 没有 AGENTS.md
[ ] 没有文档化的架构约束
[ ] 没有自动化测试
[ ] Agent 每次都从零理解项目

Level 1 - 基础 Harness
[ ] 有 AGENTS.md（<100行索引）
[ ] 有基本的 docs/ 结构
[ ] npm test / lint / typecheck 可用
[ ] pre-commit hook 配置

Level 2 - 约束 Harness
[ ] 架构约束通过 CI 机械化执行
[ ] 错误消息包含修复指引
[ ] 所有团队知识在仓库中
[ ] PR 模板和审查清单

Level 3 - 可观测 Harness
[ ] 结构化日志（Agent 可查询）
[ ] 浏览器自动化集成
[ ] Per-worktree 隔离环境
[ ] 测试输出机器可读

Level 4 - 自主 Harness
[ ] Agent 可端到端自主工作
[ ] 自动熵管理（文档清理 Agent）
[ ] Sub-Agent 编排策略
[ ] 度量体系对 Agent 可见
[ ] 快速回滚机制
[ ] 人类只审核意图，不审核代码
```

---

> **核心心智模型: 你不再是写代码的人。你是设计一个环境的人，让 AI 在这个环境中可靠地写出你想要的代码。Harness 的质量决定了 AI 产出的质量。每次 Agent 犯错，不要修复代码 -- 修复环境，让这类错误永远不再发生。**
