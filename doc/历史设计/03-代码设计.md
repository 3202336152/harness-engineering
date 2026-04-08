# 03 -- 代码设计

> Harness Engineering Skill | 版本 1.0

---

## 1. SKILL.md 设计

### 1.1 Frontmatter

```yaml
---
name: harness-engineering
description: >
  Scaffold, audit, and maintain AI coding agent work environments using
  Harness Engineering principles. Initializes AGENTS.md, architecture
  constraints, feedback loops, and entropy management systems.
  Use when: user mentions "harness", "init project structure", "AGENTS.md",
  "architecture constraints", "code audit", "entropy management",
  "harness maturity", or asks to optimize the project environment for
  AI coding agents.
license: MIT
compatibility: Requires bash and git. Works with any language or framework.
metadata:
  author: "<owner>"
  version: "1.0.0"
  tags: "harness-engineering, agent-environment, scaffolding, code-quality"
allowed-tools: Bash(git:*) Bash(jq:*) Read Write Edit Glob Grep
---
```

**规范合规检查:**

| 字段 | 规范要求 | 实际值 | 合规 |
|------|----------|--------|------|
| name | 1-64 字符，小写+连字符 | `harness-engineering` (20 字符) | OK |
| name | 不以连字符开头/结尾 | `h...g` | OK |
| name | 无连续连字符 | 无 `--` | OK |
| name | 与目录名一致 | 仓库根目录名 = `harness-engineering` | OK |
| description | 1-1024 字符 | ~380 字符 | OK |
| compatibility | 1-500 字符 | ~60 字符 | OK |
| metadata | string->string map | author, version, tags | OK |

### 1.2 Body 结构（伪代码，具体内容见实现）

```markdown
# Harness Engineering                           # ~3 行标题

## Overview                                      # ~20 行
  - 定义 + 公式 + 能力概览

## Command: /harness init                        # ~80 行
  - 触发条件
  - Agent 执行流程 (7步)
  - 脚本调用方式: `bash <skill-dir>/scripts/init-harness.sh`
  - JSON 输出字段说明
  - 初始化后引导提示

## Command: /harness audit                       # ~80 行
  - 触发条件
  - 8 维度说明表
  - 评分规则
  - 成熟度等级映射表
  - 脚本调用方式
  - JSON 输出字段说明
  - 修复建议处理规则

## Command: /harness plan                        # ~60 行
  - 触发条件
  - 输入格式 (目标+约束+验收)
  - 执行计划模板
  - exec-plans/ 目录集成

## Architecture Constraints Quick Reference      # ~60 行
  - 分层模型速查表 (Types->Config->Repo->Service->Runtime->UI)
  - 依赖方向规则
  - 跨域通信规则 (Providers)
  - 链接: references/ARCHITECTURE-PATTERNS.md

## Context Engineering Quick Reference           # ~40 行
  - AGENTS.md 100 行原则
  - 渐进式披露三层模型
  - 仓库即真理原则

## Entropy Management Quick Reference            # ~30 行
  - 黄金原则清单
  - 自动清理策略概述

## Anti-Patterns                                 # ~30 行
  - 10 个反模式，每个一行

## References                                    # ~10 行
  - references/ 文件列表和用途
```

---

## 2. init-harness.sh 详细设计

### 2.1 算法流程

```
函数: main()
  1. parse_args "$@"                    # 解析命令行参数
  2. detect_environment()               # 检测 git / 已有文件 / 技术栈
  3. if DRY_RUN; then
       print_plan()                     # 仅打印计划
       exit 0
     fi
  4. create_directories()               # 创建 docs/ 目录结构
  5. generate_files()                   # 从模板生成文件
  6. output_report()                    # 输出 JSON 报告

函数: parse_args()
  遍历 "$@"，设置全局变量:
    PROJECT_NAME (--project-name, 默认 basename of pwd)
    DESCRIPTION  (--description, 默认 "")
    FORCE        (--force, 默认 false)
    DRY_RUN      (--dry-run, 默认 false)

函数: detect_environment()
  1. 检测 .git/ 存在 -> IS_GIT=true/false
     如果 IS_GIT=false，输出警告但不退出（允许非 git 项目）
  2. 检测已有文件:
     HAS_AGENTS_MD = test -f AGENTS.md
     HAS_CLAUDE_MD = test -f CLAUDE.md
  3. 检测技术栈:
     if   test -f package.json;    then STACK="node"
     elif test -f pyproject.toml || test -f setup.py; then STACK="python"
     elif test -f go.mod;          then STACK="go"
     elif test -f Cargo.toml;      then STACK="rust"
     else STACK="unknown"
     fi

函数: create_directories()
  DIRS=(
    "docs"
    "docs/design-docs"
    "docs/exec-plans/active"
    "docs/exec-plans/completed"
    "docs/exec-plans/tech-debt"
    "docs/product-specs"
    "docs/references"
    ".github"
  )
  for dir in "${DIRS[@]}"; do
    mkdir -p "$dir"
    CREATED_DIRS+=("$dir")
  done

函数: generate_files()
  获取 SKILL_DIR 路径
  TEMPLATES_DIR="$SKILL_DIR/assets/templates"

  文件映射表:
    AGENTS.md.tpl     -> AGENTS.md
    CLAUDE.md.tpl     -> CLAUDE.md
    CONVENTIONS.md.tpl -> docs/CONVENTIONS.md
    ARCHITECTURE.md.tpl -> docs/ARCHITECTURE.md
    TESTING.md.tpl    -> docs/TESTING.md
    SECURITY.md.tpl   -> docs/SECURITY.md
    PR_TEMPLATE.md.tpl -> .github/PULL_REQUEST_TEMPLATE.md
    core-beliefs.md.tpl -> docs/design-docs/core-beliefs.md

  根据 STACK 生成 STACK_COMMANDS:
    node:    "npm install / npm run dev / npm test / npm run lint / npm run typecheck / npm run build"
    python:  "pip install -e . / python -m pytest / ruff check / mypy ."
    go:      "go build ./... / go test ./... / golangci-lint run"
    rust:    "cargo build / cargo test / cargo clippy"
    unknown: "<install> / <dev> / <test> / <lint> / <typecheck>"

  根据 STACK 生成 TEST_COMMAND:
    node: "npm test", python: "pytest", go: "go test ./...", rust: "cargo test"

  for 每个映射:
    目标文件 = 映射表[模板]
    if 文件已存在 && !FORCE:
      SKIPPED_FILES+=("$目标文件")
      continue
    fi
    读取模板 -> sed 替换占位符 -> 写入目标文件
    CREATED_FILES+=("$目标文件")

函数: output_report()
  生成 JSON:
    status, project, created_files, created_dirs,
    skipped_files, detected_stack, next_steps
  输出到 stdout
```

### 2.2 占位符替换规则

| 占位符 | 来源 | 默认值 |
|--------|------|--------|
| `{{PROJECT_NAME}}` | --project-name 或 `basename $(pwd)` | 目录名 |
| `{{DESCRIPTION}}` | --description | "TODO: Add project description" |
| `{{STACK_COMMANDS}}` | detect_environment() 结果 | 通用占位符 |
| `{{TEST_COMMAND}}` | detect_environment() 结果 | "npm test" |

### 2.3 错误处理

| 错误场景 | 处理方式 |
|----------|----------|
| 无写入权限 | 输出 JSON error 字段，exit 1 |
| 模板文件缺失 | 输出警告，跳过该文件，继续执行 |
| 部分文件创建失败 | 报告已创建和失败的文件，exit 1 |
| 非 git 仓库 | 输出警告但继续（不强制要求 git）|

---

## 3. audit-harness.sh 详细设计

### 3.1 算法流程

```
函数: main()
  1. parse_args "$@"
  2. score_all_dimensions()
  3. calculate_overall()
  4. generate_fixes()
  5. output_report()

函数: score_all_dimensions()
  调用 8 个独立评分函数，每个返回 0-100:
    score_entry_document()
    score_doc_structure()
    score_doc_freshness()
    score_architecture_constraints()
    score_test_coverage()
    score_automation()
    score_exec_plans()
    score_security_governance()

函数: calculate_overall()
  权重表:
    entry_document: 0.15
    doc_structure: 0.15
    doc_freshness: 0.10
    architecture_constraints: 0.15
    test_coverage: 0.15
    automation: 0.10
    exec_plans: 0.10
    security_governance: 0.10

  overall = sum(score[i] * weight[i])

  成熟度映射:
    90-100 -> Level 4, "Autonomous Harness"
    70-89  -> Level 3, "Observable Harness"
    50-69  -> Level 2, "Constrained Harness"
    25-49  -> Level 1, "Basic Harness"
    0-24   -> Level 0, "No Harness"
```

### 3.2 各维度评分逻辑

#### 维度 1: 入口文档 (entry_document, 15%)

```
score = 0, details = []

if AGENTS.md 或 CLAUDE.md 存在:
  score += 40
  details += "Entry document found"

  if 文件行数 <= 100:
    score += 30
    details += "Under 100 lines (good)"
  elif 文件行数 <= 150:
    score += 15
    details += "Over 100 lines, consider trimming"

  if 包含 "## 快速命令" 或 "## Quick Commands":
    score += 10
    details += "Has quick commands section"

  if 包含 "## 架构" 或 "## Architecture":
    score += 10
    details += "Has architecture section"

  if 包含 "## 约束" 或 "## Constraints":
    score += 10
    details += "Has constraints section"
else:
  score = 0
  details += "No AGENTS.md or CLAUDE.md found"
  fix = "Run /harness init to create entry documents"
```

#### 维度 2: 文档结构 (doc_structure, 15%)

```
score = 0

核心文档列表:
  docs/ARCHITECTURE.md  (25分)
  docs/CONVENTIONS.md   (25分)
  docs/TESTING.md       (25分)
  docs/SECURITY.md      (25分)

for 每个核心文档:
  if 文件存在 && 行数 > 5:
    score += 25
    details += "$file exists with content"
  elif 文件存在:
    score += 10
    details += "$file exists but appears empty"
  else:
    details += "$file missing"
```

#### 维度 3: 文档新鲜度 (doc_freshness, 10%)

```
if 非 git 仓库:
  score = 50
  details += "Not a git repo, cannot check freshness"
  return

stale_count = 0
total_count = 0

for 每个 docs/*.md:
  total_count++
  last_modified = git log -1 --format="%ct" -- "$file"
  age_days = (now - last_modified) / 86400

  if age_days > 30:
    stale_count++
    stale_files += "$file ($age_days days)"

if total_count == 0:
  score = 0
else:
  fresh_ratio = (total_count - stale_count) / total_count
  score = fresh_ratio * 100
```

#### 维度 4: 架构约束 (architecture_constraints, 15%)

```
score = 0

if 存在 scripts/lint-architecture.sh 或 .harness/architecture.json:
  score += 40
  details += "Architecture validation script found"

if 存在 .eslintrc* 或 .ruff.toml 或 golangci-lint 配置:
  score += 20
  details += "Linter configuration found"

if CI 配置中包含 "architecture" 或 "lint-arch" 或 "boundary":
  score += 20
  details += "Architecture check in CI"

if docs/ARCHITECTURE.md 中包含 "layer" 或 "dependency" 或 "boundary":
  score += 20
  details += "Architecture document has constraint descriptions"
```

#### 维度 5: 测试覆盖 (test_coverage, 15%)

```
score = 0

if package.json 包含 "test" script 或 pyproject.toml 包含 pytest 或 存在 go.mod:
  score += 30
  details += "Test command configured"

if 存在 tests/ 或 __tests__/ 或 *_test.go 或 test_*.py:
  score += 30
  details += "Test directory/files found"

if CI 配置中包含 "test" step:
  score += 20
  details += "Tests in CI pipeline"

if 存在 coverage 配置 (jest.config 中 coverage 或 pytest-cov):
  score += 20
  details += "Coverage reporting configured"
```

#### 维度 6: 自动化 (automation, 10%)

```
score = 0

if 存在 .github/workflows/*.yml 或 .gitlab-ci.yml:
  score += 50
  details += "CI pipeline found"

if 存在 .husky/ 或 .git/hooks/pre-commit 或 pre-commit-config.yaml:
  score += 30
  details += "Pre-commit hooks configured"

if 存在 .github/PULL_REQUEST_TEMPLATE.md:
  score += 20
  details += "PR template found"
```

#### 维度 7: 执行计划 (exec_plans, 10%)

```
score = 0

if 存在 docs/exec-plans/:
  score += 40
  details += "exec-plans directory exists"

  if 存在 docs/exec-plans/active/:
    score += 20

  if 存在 docs/exec-plans/completed/:
    score += 20

  if docs/exec-plans/ 下有 .md 文件:
    score += 20
    details += "Has execution plan files"
```

#### 维度 8: 安全治理 (security_governance, 10%)

```
score = 0

if .gitignore 中包含 ".env":
  score += 30
  details += ".env in .gitignore"

if 存在 docs/SECURITY.md 或 SECURITY.md:
  score += 30
  details += "Security documentation found"

if .gitignore 中包含 "credentials" 或 "secret" 或 "*.key":
  score += 20
  details += "Sensitive files in .gitignore"

if 存在 CODEOWNERS:
  score += 20
  details += "CODEOWNERS configured"
```

### 3.3 修复建议生成

```
函数: generate_fixes()

  fixes = []
  priority = 1

  # 按分数从低到高排序维度
  sorted_dims = sort dimensions by score ASC

  for dim in sorted_dims:
    if dim.score < 50:
      impact = "high"
    elif dim.score < 75:
      impact = "medium"
    else:
      impact = "low"
      continue  # 不为高分维度生成修复建议

    fixes += {
      priority: priority++,
      dimension: dim.id,
      action: dim.fix,
      impact: impact
    }

  # 最多输出 5 条修复建议
  return fixes[:5]
```

---

## 4. 模板文件设计

### 4.1 AGENTS.md.tpl

```markdown
# {{PROJECT_NAME}}

{{DESCRIPTION}}

## Quick Commands

```bash
{{STACK_COMMANDS}}
```

## Architecture Overview

[Describe the core architecture pattern of this project]

See: docs/ARCHITECTURE.md for detailed architecture documentation.

### Layered Model

Each business domain follows strict layered dependencies:

```
Types -> Config -> Repo -> Service -> Runtime -> UI
```

Dependencies flow left-to-right only. Cross-cutting concerns are injected via Providers.

## Key Constraints

1. Review docs/design-docs/core-beliefs.md before modifying core infrastructure
2. All changes must pass automated acceptance tests defined in docs/TESTING.md
3. Update relevant docs/ files before merging PRs
4. Validate data at system boundaries; internal code trusts each other
5. Prefer shared utilities over reimplementation

## Documentation Navigation

| Topic | File | Purpose |
|-------|------|---------|
| Architecture | docs/ARCHITECTURE.md | Domain structure and package layers |
| Conventions | docs/CONVENTIONS.md | Naming, formatting, code style |
| Security | docs/SECURITY.md | Auth, permissions, sensitive data |
| Testing | docs/TESTING.md | Test strategy and commands |
| Design Decisions | docs/design-docs/ | Verified architecture decisions |
| Execution Plans | docs/exec-plans/ | Current and completed plans |

## Git Workflow

- Branch naming: `feat/xxx`, `fix/xxx`, `refactor/xxx`
- Commit format: `type(scope): description`
- PRs must include test cases
- Each PR focuses on a single responsibility
```

### 4.2 CLAUDE.md.tpl

与 AGENTS.md.tpl 内容一致（由 init 脚本复制生成）。

### 4.3 ARCHITECTURE.md.tpl

```markdown
# Architecture

> {{PROJECT_NAME}} system architecture documentation.

## System Overview

[Describe the high-level system design]

## Domain Structure

[List and describe each business domain]

## Layered Model

Each domain follows this dependency hierarchy:

```
types/    -> Pure type definitions, zero dependencies
config/   -> Configuration, depends on types only
repo/     -> Data access, depends on types + config
service/  -> Business logic, depends on types + config + repo
runtime/  -> Runtime initialization, depends on all above
ui/       -> User interface, depends on all above
```

### Dependency Rules

- Dependencies flow top-to-bottom only
- Same-layer imports are forbidden
- Cross-domain dependencies only through Providers interface
- Violations are caught by CI

## Key Design Decisions

See: docs/design-docs/ for detailed records.

## Infrastructure

[Describe databases, caches, message queues, external services]
```

### 4.4 CONVENTIONS.md.tpl

```markdown
# Coding Conventions

## Naming

- Files: kebab-case (`user-service.ts`)
- Functions/Methods: camelCase (`getUserById`)
- Types/Classes: PascalCase (`UserService`)
- Constants: UPPER_SNAKE_CASE (`MAX_RETRY_COUNT`)

## Golden Rules

1. Prefer shared utilities (`src/shared/`), never duplicate implementations
2. Validate data at system boundaries; internal methods trust each other
3. Use the team's standard concurrency tools; never implement custom locks/queues
4. Single file under 300 lines; single function under 50 lines
5. Every public API must have a corresponding integration test
6. Use structured logging; never use bare `console.log`

## Code Style

[Define formatting rules, import ordering, etc.]

## Error Handling

[Define error handling patterns and conventions]
```

### 4.5 TESTING.md.tpl

```markdown
# Testing Strategy

## Commands

```bash
{{TEST_COMMAND}}              # Run all tests
```

## Test Structure

- Unit tests: co-located with source or in `tests/unit/`
- Integration tests: `tests/integration/`
- E2E tests: `tests/e2e/`

## Coverage Requirements

- New code: > 80% line coverage
- Critical paths: > 95% coverage

## Testing Guidelines

- Test behavior, not implementation
- One assertion per test when possible
- Use descriptive test names: `should_return_error_when_input_is_invalid`
- Mock external dependencies, not internal modules
```

### 4.6 SECURITY.md.tpl

```markdown
# Security

## Sensitive Data

- `.env` files are in `.gitignore` and never committed
- Credentials are stored in environment variables or secret managers
- No hardcoded secrets in source code

## Authentication

[Describe authentication flow]

## Authorization

[Describe authorization model]

## Agent Permissions

Coding agents should follow the principle of least privilege:
- Read: src/, docs/, tests/, config files
- Write: src/, tests/, docs/exec-plans/
- Execute: test, lint, typecheck, build commands
- Forbidden: .env*, credentials, npm publish, git push --force
```

### 4.7 PR_TEMPLATE.md.tpl

```markdown
## What

[One sentence describing the change]

## Why

[Motivation and linked issue/plan]

## Type

- [ ] Feature
- [ ] Bug fix
- [ ] Refactor
- [ ] Documentation
- [ ] Tests

## Checklist

- [ ] Tests pass
- [ ] Type check passes
- [ ] Lint passes
- [ ] Architecture boundary check passes
- [ ] Includes test cases for new functionality
- [ ] Documentation updated (if needed)

## Evidence

[Screenshots, test output, or performance data]
```

### 4.8 core-beliefs.md.tpl

```markdown
# Core Beliefs

> Fundamental design decisions that should not be changed without team consensus.
> Review this document before modifying core infrastructure.

## Architecture

- [Document core architectural decisions]

## Technology Choices

- [Document technology stack decisions and rationale]

## Quality Standards

- [Document quality requirements and non-negotiables]

## Performance

- [Document performance targets and constraints]
```

---

## 5. references/MATURITY-MODEL.md 设计

```markdown
# Harness Maturity Model

> Deep reference for harness-engineering skill.
> Loaded on demand by SKILL.md.

## Overview

The Harness Maturity Model defines 5 levels (0-4) of AI coding agent
environment quality. Each level builds on the previous one.

## Level Definitions

### Level 0 -- No Harness (Score: 0-24)

Characteristics:
- No AGENTS.md or CLAUDE.md
- No documented architecture constraints
- No automated testing or linting
- Agent starts from zero understanding each session

Checklist:
- [ ] None of the Level 1 items are present

### Level 1 -- Basic Harness (Score: 25-49)

Characteristics:
- Entry document exists (AGENTS.md < 100 lines)
- Basic docs/ structure
- Test/lint/typecheck commands available
- Pre-commit hooks configured

Checklist:
- [ ] AGENTS.md exists and is under 100 lines
- [ ] docs/ directory with at least ARCHITECTURE.md
- [ ] Working test command
- [ ] Working lint command
- [ ] Pre-commit hook runs lint

Upgrade path from Level 0:
- Run /harness init to generate the structure
- Fill in project-specific details in AGENTS.md
- Configure basic test and lint commands

### Level 2 -- Constrained Harness (Score: 50-69)

Characteristics:
- Architecture constraints enforced by CI
- Error messages include fix instructions
- All team knowledge is in the repository
- PR template and review checklist

Checklist:
- [ ] Architecture validation in CI pipeline
- [ ] CI error messages include FIX: guidance
- [ ] docs/CONVENTIONS.md with golden rules
- [ ] docs/design-docs/ with key decisions
- [ ] PR template with verification checklist
- [ ] No implicit knowledge outside the repo

Upgrade path from Level 1:
- Identify top 3-5 architecture constraints
- Encode them as CI checks with fix instructions
- Migrate team knowledge from Slack/Docs to repo

### Level 3 -- Observable Harness (Score: 70-89)

Characteristics:
- Structured logging (agent-queryable)
- Browser automation integration
- Per-worktree isolation
- Machine-readable test output

Checklist:
- [ ] JSON structured logging format
- [ ] Playwright/Puppeteer integration for UI verification
- [ ] Worktree-based task isolation
- [ ] Test output in JSON format
- [ ] Coverage reporting configured

Upgrade path from Level 2:
- Add structured logging format
- Configure browser automation for UI tests
- Set up worktree scripts for parallel tasks

### Level 4 -- Autonomous Harness (Score: 90-100)

Characteristics:
- Agent works end-to-end autonomously
- Automatic entropy management (doc cleanup agent)
- Sub-agent orchestration strategy
- Metrics visible to agents
- Fast rollback mechanism
- Human reviews intent only, not code

Checklist:
- [ ] Agent can discover, reproduce, fix, verify, and PR bugs
- [ ] Automatic documentation freshness enforcement
- [ ] Dead code detection and cleanup
- [ ] Sub-agent task delegation configured
- [ ] Performance metrics queryable by agent
- [ ] One-command rollback
- [ ] Average PR review time < 10 minutes

Upgrade path from Level 3:
- Configure entropy management scheduled tasks
- Design sub-agent orchestration strategy
- Make all metrics agent-queryable

## Scoring System

Each audit dimension scores 0-100 independently.
Overall score = weighted average of all dimensions.

Weights:
- Entry Document: 15%
- Documentation Structure: 15%
- Documentation Freshness: 10%
- Architecture Constraints: 15%
- Test Coverage: 15%
- Automation: 10%
- Execution Plans: 10%
- Security Governance: 10%

## Related

- SKILL.md /harness audit command
- references/METRICS.md (Phase 3)
```

该文件约 120 行，在 200 行限制内。
