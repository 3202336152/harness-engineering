# 06 -- 发布指南

> Harness Engineering Skill | 版本 1.0

---

## 1. skills.sh 发布流程

### 1.1 前置条件

- [ ] GitHub 账户
- [ ] 公开 GitHub 仓库，名称为 `harness-engineering`
- [ ] 仓库根目录包含 `SKILL.md`
- [ ] SKILL.md 通过 `skills-ref validate .` 验证
- [ ] 所有测试通过 (`bash tests/run-tests.sh`)

### 1.2 发布步骤

skills.sh 的索引机制基于 GitHub 仓库。不需要手动提交到某个注册中心。流程如下：

```
步骤 1: 准备仓库
  ├── 创建 GitHub 仓库: <owner>/harness-engineering
  ├── 确保仓库是 public
  ├── 确保 SKILL.md 在仓库根目录
  └── 确保 name 字段 = 仓库名 = "harness-engineering"

步骤 2: 本地验证
  $ cd harness-engineering
  $ skills-ref validate .          # 规范验证
  $ bash tests/run-tests.sh        # 运行测试

步骤 3: 打 tag 和 release
  $ git tag v1.0.0
  $ git push origin main --tags
  $ gh release create v1.0.0 --title "v1.0.0 - Initial Release" \
      --notes "Phase 1: Core scaffold with init, audit, and plan commands."

步骤 4: 验证安装
  $ npx skills add <owner>/harness-engineering
  # 确认文件被安装到 ~/.claude/skills/harness-engineering/

步骤 5: 提交到 skills.sh 索引（可选）
  skills.sh 通过 telemetry 自动发现已安装的 skill。
  但也可以主动提交:
  - 访问 skills.sh
  - 如有提交入口，填写 GitHub 仓库 URL
  - 或等待自然发现（用户安装后自动上报）
```

### 1.3 安装验证清单

安装后逐项验证：

```bash
# 1. 检查文件是否完整
ls ~/.claude/skills/harness-engineering/
# 应包含: SKILL.md, scripts/, references/, assets/

# 2. 检查脚本可执行
bash ~/.claude/skills/harness-engineering/scripts/init-harness.sh --dry-run
# 应输出 JSON

# 3. 检查脚本路径解析
bash ~/.claude/skills/harness-engineering/scripts/audit-harness.sh
# 应能找到 assets/templates/

# 4. 在 Claude Code 中测试
# 打开一个新项目，输入 /harness init
# 观察是否正常触发
```

---

## 2. 多 Agent 安装

### 2.1 支持的 Agent

| Agent | 安装命令 | 安装路径 |
|-------|----------|----------|
| Claude Code | `npx skills add <owner>/harness-engineering` | `~/.claude/skills/harness-engineering/` |
| Codex | `npx skills add -a codex <owner>/harness-engineering` | `~/.codex/skills/harness-engineering/` |
| Cursor | `npx skills add -a cursor <owner>/harness-engineering` | 项目级或全局 |
| OpenCode | `npx skills add -a opencode <owner>/harness-engineering` | `~/.opencode/skills/` |
| 项目级 | `npx skills add --project <owner>/harness-engineering` | `.skills/harness-engineering/` |

### 2.2 全局 vs 项目级

| 安装方式 | 场景 | 命令 |
|----------|------|------|
| 全局安装 | 所有项目都能使用 | `npx skills add <owner>/harness-engineering` |
| 项目级安装 | 仅特定项目使用，团队共享 | `npx skills add --project <owner>/harness-engineering` |

推荐：首次使用全局安装，团队协作时项目级安装并提交 `.skills/` 到仓库。

---

## 3. 版本策略

### 3.1 语义化版本

```
MAJOR.MINOR.PATCH

MAJOR: 破坏性变更（SKILL.md 接口改变、脚本参数不兼容）
MINOR: 新功能（新命令、新审计维度、新模板）
PATCH: 修复（评分逻辑修正、模板内容改进、文档更新）
```

### 3.2 版本路线图

| 版本 | 内容 | 对应阶段 |
|------|------|----------|
| v1.0.0 | 核心骨架：init + audit + plan + MATURITY-MODEL | Phase 1 |
| v1.1.0 | 深层参考：ARCHITECTURE-PATTERNS, AGENTS-MD-GUIDE 等 | Phase 2 |
| v1.2.0 | lint-architecture.sh + check-doc-freshness.sh | Phase 3 |
| v1.3.0 | CI 模板 + 剩余参考文档 | Phase 3 |
| v2.0.0 | 如果 Agent Skills 规范有破坏性更新 | 按需 |

### 3.3 版本发布流程

```bash
# 1. 更新 SKILL.md frontmatter 中的 version
sed -i 's/version: "1.0.0"/version: "1.1.0"/' SKILL.md

# 2. 更新 CHANGELOG.md (如果有)

# 3. 提交
git add -A
git commit -m "chore: bump version to 1.1.0"

# 4. 打 tag
git tag v1.1.0

# 5. 推送
git push origin main --tags

# 6. 创建 GitHub Release
gh release create v1.1.0 --generate-notes
```

---

## 4. CI/CD 配置

### 4.1 GitHub Actions

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Validate SKILL.md
        run: |
          # 检查 name 字段格式
          name=$(sed -n '/^---$/,/^---$/p' SKILL.md | grep "^name:" | sed 's/name: *//')
          echo "Skill name: $name"
          echo "$name" | grep -qE '^[a-z][a-z0-9]*(-[a-z0-9]+)*$' || {
            echo "ERROR: Invalid skill name format"
            exit 1
          }

          # 检查 body 行数
          body_start=$(grep -n "^---$" SKILL.md | tail -1 | cut -d: -f1)
          total_lines=$(wc -l < SKILL.md)
          body_lines=$((total_lines - body_start))
          echo "SKILL.md body lines: $body_lines"
          [ "$body_lines" -lt 500 ] || {
            echo "ERROR: SKILL.md body exceeds 500 lines ($body_lines)"
            exit 1
          }

  test:
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - name: Run tests
        run: bash tests/run-tests.sh

  release:
    needs: [validate, test]
    if: startsWith(github.ref, 'refs/tags/v')
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v4
      - name: Create GitHub Release
        run: gh release create "${{ github.ref_name }}" --generate-notes
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

---

## 5. README.md 设计

仓库的 README.md（非 Skill 规范要求，是给 GitHub 用户看的）：

```markdown
# harness-engineering

An Agent Skill for scaffolding, auditing, and maintaining AI coding agent
work environments using Harness Engineering principles.

## Install

```bash
npx skills add <owner>/harness-engineering
```

## Commands

| Command | Description |
|---------|-------------|
| `/harness init` | Initialize Harness structure in your project |
| `/harness audit` | Audit your project's Harness health score |
| `/harness plan` | Generate a structured execution plan |

## What is Harness Engineering?

> Coding Agent = AI Model + Harness

The model is commoditizing. The Harness is the real competitive advantage.

This skill helps you build the Harness: entry documents, architecture
constraints, feedback loops, and entropy management systems that make
AI coding agents work reliably at scale.

## Compatibility

Works with 40+ AI coding agents including Claude Code, Codex, Cursor,
and more. Requires bash and git.

## License

MIT
```

---

## 6. 发布前最终检查清单

- [ ] SKILL.md frontmatter 所有字段正确
- [ ] SKILL.md body < 500 行
- [ ] 所有 scripts/ 脚本有 `#!/bin/bash` shebang
- [ ] 所有 scripts/ 脚本有执行权限 (`chmod +x`)
- [ ] 脚本内部的 SKILL_DIR 路径解析正确
- [ ] 模板文件中的占位符与脚本中的替换逻辑一致
- [ ] tests/run-tests.sh 全部通过
- [ ] README.md 内容准确
- [ ] LICENSE 文件存在 (MIT)
- [ ] .gitignore 包含 tests/tmp/
- [ ] Git tag 与 metadata.version 一致
- [ ] `npx skills add .` 本地安装测试通过
