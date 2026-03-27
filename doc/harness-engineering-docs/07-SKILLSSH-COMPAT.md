# 07 -- skills.sh 适配清单

> Harness Engineering Skill | 版本 1.0
> 规范来源: agentskills.io/specification (Agent Skills Open Standard)

---

## 1. 规范逐项对照

### 1.1 目录结构合规

| 规范要求 | 实际设计 | 合规 | 备注 |
|----------|----------|------|------|
| Skill 是一个目录 | `harness-engineering/` | OK | |
| 目录至少包含 SKILL.md | `harness-engineering/SKILL.md` | OK | |
| 可选: scripts/ | `scripts/init-harness.sh`, `scripts/audit-harness.sh` | OK | |
| 可选: references/ | `references/MATURITY-MODEL.md` | OK | |
| 可选: assets/ | `assets/templates/*.tpl` | OK | |

### 1.2 SKILL.md Frontmatter 合规

| 字段 | 规范要求 | 实际值 | 合规 |
|------|----------|--------|------|
| `name` (必须) | 1-64 字符，小写字母+数字+连字符 | `harness-engineering` (20 字符) | OK |
| | 不以连字符开头/结尾 | `h...g` | OK |
| | 无连续连字符 | 无 `--` | OK |
| | 与父目录名一致 | 仓库名 = `harness-engineering` | OK |
| `description` (必须) | 1-1024 字符，非空 | ~380 字符 | OK |
| | 描述做什么 + 何时使用 | 包含 "Use when:" 段 | OK |
| | 包含触发关键词 | harness, init, audit, AGENTS.md 等 | OK |
| `license` (可选) | 许可证名称 | `MIT` | OK |
| `compatibility` (可选) | 1-500 字符 | ~60 字符 | OK |
| `metadata` (可选) | string->string map | author, version, tags | OK |
| `allowed-tools` (可选) | 空格分隔的工具列表 | `Bash(git:*) Bash(jq:*) Read Write Edit Glob Grep` | OK |

### 1.3 Body Content 合规

| 规范要求 | 实际设计 | 合规 |
|----------|----------|------|
| Markdown 格式 | 标准 Markdown | OK |
| 无格式限制 | N/A | OK |
| 推荐: 步骤说明 | 三大命令各有详细步骤 | OK |
| 推荐: 输入输出示例 | JSON 输出示例 | OK |
| 推荐: 边缘情况 | 反模式清单 | OK |
| 推荐: < 500 行 | ~415 行设计 | OK |
| 长内容拆到 references | 成熟度模型在 references/ | OK |

### 1.4 渐进式披露合规

| 层级 | 规范建议 | 实际设计 | 合规 |
|------|----------|----------|------|
| 元数据 (~100 tokens) | name + description 启动加载 | frontmatter ~15 行 | OK |
| 指令 (< 5000 tokens) | SKILL.md body 激活时加载 | ~415 行 < 500 行 | OK |
| 资源 (按需) | scripts/, references/, assets/ | 由 Agent 根据指令按需读取/执行 | OK |

### 1.5 文件引用合规

| 规范要求 | 实际设计 | 合规 |
|----------|----------|------|
| 使用相对路径 | `scripts/init-harness.sh`, `references/MATURITY-MODEL.md` | OK |
| 保持一层深度 | 所有引用直接从 SKILL.md 指向一级子目录 | OK |
| 避免深层引用链 | reference 文档之间不互相引用（Phase 1） | OK |

---

## 2. skills CLI 兼容性

### 2.1 安装方式

| 命令 | 预期行为 | 需要验证 |
|------|----------|----------|
| `npx skills add <owner>/harness-engineering` | 克隆到 `~/.claude/skills/harness-engineering/` | Y |
| `npx skills add -a codex <owner>/harness-engineering` | 克隆到 Codex skills 目录 | Y |
| `npx skills add --project <owner>/harness-engineering` | 克隆到 `.skills/harness-engineering/` | Y |
| `npx skills remove harness-engineering` | 删除已安装的 skill | Y |
| `npx skills list` | 列出已安装 skill，包含 harness-engineering | Y |
| `npx skills check` | 检查 skill 健康状态 | Y |
| `npx skills update harness-engineering` | 更新到最新版本 | Y |

### 2.2 安装来源支持

| 来源格式 | 示例 | 支持 |
|----------|------|------|
| GitHub 简写 | `<owner>/harness-engineering` | Y |
| GitHub URL | `https://github.com/<owner>/harness-engineering` | Y |
| Git URL | `git@github.com:<owner>/harness-engineering.git` | Y |
| 本地路径 | `./path/to/harness-engineering` | Y |

---

## 3. Agent 兼容性矩阵

### 3.1 Claude Code

| 特性 | 支持情况 | 备注 |
|------|----------|------|
| SKILL.md 自动加载 | 支持 | 安装后 description 匹配触发 |
| scripts/ 执行 | 支持 | 通过 Bash tool |
| references/ 读取 | 支持 | 通过 Read tool |
| assets/ 读取 | 支持 | 通过 Read tool |
| allowed-tools | 支持 (实验性) | 预授权指定工具 |
| Slash command `/harness` | 需验证 | 取决于 Claude Code 版本 |

### 3.2 OpenAI Codex

| 特性 | 支持情况 | 备注 |
|------|----------|------|
| SKILL.md 加载 | 通过 AGENTS.md 引用 | Codex 原生读 AGENTS.md |
| scripts/ 执行 | 支持 | sandbox 中执行 |
| 上下文预算 | 65536 bytes 默认 | SKILL.md 在预算内 |

### 3.3 Cursor

| 特性 | 支持情况 | 备注 |
|------|----------|------|
| SKILL.md 加载 | 通过 .cursorrules 引用 | 需要手动引用 |
| scripts/ 执行 | 支持 | 通过 terminal |
| @docs 引用 | 支持 | 可引用 references/ |

---

## 4. 已知限制与规避

| 限制 | 影响 | 规避方案 |
|------|------|----------|
| bash 3.2 (macOS 默认) 不支持关联数组 | 脚本兼容性 | 不使用 `declare -A` |
| skills-ref validate 可能不可用 | 无法自动验证 | 手动检查 + CI 自定义验证 |
| allowed-tools 是实验性字段 | 部分 Agent 可能忽略 | 在 SKILL.md body 中也声明工具需求 |
| 不同 Agent 的 skills 目录不同 | 安装路径差异 | 使用 `npx skills add -a <agent>` |
| SKILL.md body 没有行数强制限制 | 只是推荐 < 500 行 | 自我约束 + CI 检查 |

---

## 5. skills.sh 排名因素

skills.sh 通过以下因素排名 skill（基于观察）：

| 因素 | 影响 | 本 Skill 策略 |
|------|------|---------------|
| 安装量 | 高 | README 清晰、安装命令简单 |
| GitHub stars | 中 | 高质量内容吸引自然 star |
| 描述质量 | 中 | description 包含精准触发词 |
| 更新频率 | 低 | 按 Phase 定期发布新版本 |

---

## 6. 合规验证脚本

以下脚本可在 CI 中运行，验证规范合规性：

```bash
#!/bin/bash
# verify-spec-compliance.sh
set -euo pipefail

SKILL_FILE="SKILL.md"
ERRORS=0

echo "Verifying Agent Skills specification compliance..."

# 1. SKILL.md 存在
if [ ! -f "$SKILL_FILE" ]; then
  echo "FAIL: $SKILL_FILE not found"
  exit 1
fi

# 2. 有 YAML frontmatter
if ! head -1 "$SKILL_FILE" | grep -q "^---$"; then
  echo "FAIL: No YAML frontmatter"
  ERRORS=$((ERRORS + 1))
fi

# 3. name 字段
NAME=$(sed -n '/^---$/,/^---$/p' "$SKILL_FILE" | grep "^name:" | sed 's/name: *//')
if [ -z "$NAME" ]; then
  echo "FAIL: Missing name field"
  ERRORS=$((ERRORS + 1))
else
  # 长度检查
  if [ ${#NAME} -gt 64 ]; then
    echo "FAIL: name exceeds 64 characters (${#NAME})"
    ERRORS=$((ERRORS + 1))
  fi
  # 格式检查
  if ! echo "$NAME" | grep -qE '^[a-z][a-z0-9]*(-[a-z0-9]+)*$'; then
    echo "FAIL: name format invalid: $NAME"
    ERRORS=$((ERRORS + 1))
  fi
  # 连续连字符检查
  if echo "$NAME" | grep -q '\-\-'; then
    echo "FAIL: name contains consecutive hyphens"
    ERRORS=$((ERRORS + 1))
  fi
  # 目录名一致性
  DIR_NAME=$(basename "$(pwd)")
  if [ "$NAME" != "$DIR_NAME" ]; then
    echo "WARN: name ($NAME) does not match directory ($DIR_NAME)"
  fi
  echo "OK: name = $NAME"
fi

# 4. description 字段
DESC=$(sed -n '/^---$/,/^---$/{ /^description:/,/^[a-z]/{ /^description:/s/description: *//p; /^  /p; }}' "$SKILL_FILE" | tr -d '\n' | sed 's/^ *//')
if [ -z "$DESC" ]; then
  echo "FAIL: Missing or empty description field"
  ERRORS=$((ERRORS + 1))
else
  DESC_LEN=${#DESC}
  if [ "$DESC_LEN" -gt 1024 ]; then
    echo "FAIL: description exceeds 1024 characters ($DESC_LEN)"
    ERRORS=$((ERRORS + 1))
  fi
  echo "OK: description ($DESC_LEN chars)"
fi

# 5. Body 行数
FRONTMATTER_END=$(grep -n "^---$" "$SKILL_FILE" | tail -1 | cut -d: -f1)
TOTAL_LINES=$(wc -l < "$SKILL_FILE")
BODY_LINES=$((TOTAL_LINES - FRONTMATTER_END))
if [ "$BODY_LINES" -ge 500 ]; then
  echo "WARN: SKILL.md body is $BODY_LINES lines (recommended < 500)"
fi
echo "OK: body = $BODY_LINES lines"

# 6. 结果
echo ""
if [ "$ERRORS" -gt 0 ]; then
  echo "FAILED: $ERRORS compliance error(s)"
  exit 1
fi
echo "PASSED: All specification checks passed"
```

---

## 7. 总结

本 Skill 的设计完全遵循 Agent Skills 开放标准（agentskills.io/specification），可以通过以下方式验证合规性：

1. `skills-ref validate .` -- 官方验证工具
2. `bash verify-spec-compliance.sh` -- 自定义验证脚本
3. `bash tests/test-skillmd.sh` -- SKILL.md 专项测试
4. CI pipeline -- 每次提交自动检查

通过 `npx skills add` 安装后，可被 40+ AI 编码代理自动识别和使用。
