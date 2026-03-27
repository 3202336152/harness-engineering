# 05 -- 测试计划

> Harness Engineering Skill | 版本 1.0

---

## 1. 测试策略概览

### 1.1 测试层次

```
Layer 1: 规范合规测试 (Spec Compliance)
  └── SKILL.md 是否符合 Agent Skills 规范

Layer 2: 脚本单元测试 (Script Unit Tests)
  ├── init-harness.sh 各函数独立测试
  └── audit-harness.sh 各评分函数独立测试

Layer 3: 集成测试 (Integration Tests)
  ├── init -> 完整的文件生成验证
  └── audit -> 不同项目状态的评分验证

Layer 4: 端到端测试 (E2E Tests)
  ├── 安装测试: npx skills add 能否成功安装
  └── Agent 调用测试: Claude Code 中能否正常触发
```

### 1.2 测试工具

| 工具 | 用途 |
|------|------|
| bash 脚本 | 测试执行框架（零依赖） |
| `skills-ref validate` | SKILL.md 规范验证 |
| jq | JSON 输出解析验证 |
| diff | 文件内容对比 |
| git | 创建测试用仓库 |

### 1.3 测试目录结构

```
tests/
├── run-tests.sh                # 测试入口，运行所有测试
├── test-helpers.sh             # 共用辅助函数
├── test-init.sh                # init 脚本测试集
├── test-audit.sh               # audit 脚本测试集
├── test-skillmd.sh             # SKILL.md 规范测试
├── fixtures/
│   ├── empty-project/          # 空 git 仓库
│   ├── basic-node-project/     # 有 package.json 的项目
│   │   └── package.json
│   ├── basic-python-project/   # 有 pyproject.toml 的项目
│   │   └── pyproject.toml
│   ├── basic-go-project/       # 有 go.mod 的项目
│   │   └── go.mod
│   ├── basic-rust-project/     # 有 Cargo.toml 的项目
│   │   └── Cargo.toml
│   ├── partial-harness/        # 部分 Harness 的项目
│   │   ├── AGENTS.md
│   │   └── docs/
│   │       └── ARCHITECTURE.md
│   └── full-harness/           # 完整 Harness 的项目
│       ├── AGENTS.md
│       ├── CLAUDE.md
│       ├── .gitignore          # 包含 .env
│       ├── .github/
│       │   ├── workflows/
│       │   │   └── ci.yml
│       │   └── PULL_REQUEST_TEMPLATE.md
│       ├── docs/
│       │   ├── ARCHITECTURE.md
│       │   ├── CONVENTIONS.md
│       │   ├── TESTING.md
│       │   ├── SECURITY.md
│       │   ├── design-docs/
│       │   │   └── core-beliefs.md
│       │   └── exec-plans/
│       │       ├── active/
│       │       │   └── sample-plan.md
│       │       └── completed/
│       ├── scripts/
│       │   └── lint-architecture.sh
│       ├── .husky/
│       │   └── pre-commit
│       ├── src/
│       │   └── index.ts
│       └── tests/
│           └── index.test.ts
└── tmp/                        # 测试运行时临时目录（.gitignore）
```

---

## 2. 测试辅助框架

### 2.1 test-helpers.sh

```bash
#!/bin/bash
# 简易测试框架，零依赖

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
CURRENT_TEST=""

setup_test_dir() {
  # 创建临时测试目录
  TEST_TMP="$(mktemp -d)"
  cd "$TEST_TMP" || exit 1
  git init --quiet
}

teardown_test_dir() {
  cd /
  rm -rf "$TEST_TMP"
}

describe() {
  echo ""
  echo "=== $1 ==="
}

it() {
  CURRENT_TEST="$1"
  TESTS_RUN=$((TESTS_RUN + 1))
}

assert_eq() {
  local expected="$1" actual="$2" msg="${3:-}"
  if [ "$expected" = "$actual" ]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  PASS: $CURRENT_TEST${msg:+ ($msg)}"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  FAIL: $CURRENT_TEST${msg:+ ($msg)}"
    echo "    expected: $expected"
    echo "    actual:   $actual"
  fi
}

assert_file_exists() {
  local file="$1"
  if [ -f "$file" ]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  PASS: $CURRENT_TEST (file exists: $file)"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  FAIL: $CURRENT_TEST (file not found: $file)"
  fi
}

assert_dir_exists() {
  local dir="$1"
  if [ -d "$dir" ]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  PASS: $CURRENT_TEST (dir exists: $dir)"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  FAIL: $CURRENT_TEST (dir not found: $dir)"
  fi
}

assert_file_not_exists() {
  local file="$1"
  if [ ! -f "$file" ]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  PASS: $CURRENT_TEST (file does not exist: $file)"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  FAIL: $CURRENT_TEST (file unexpectedly exists: $file)"
  fi
}

assert_file_contains() {
  local file="$1" pattern="$2"
  if grep -q "$pattern" "$file" 2>/dev/null; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  PASS: $CURRENT_TEST (contains: $pattern)"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  FAIL: $CURRENT_TEST ($file does not contain: $pattern)"
  fi
}

assert_json_field() {
  local json="$1" field="$2" expected="$3"
  local actual
  actual=$(echo "$json" | jq -r "$field")
  assert_eq "$expected" "$actual" "JSON $field"
}

print_summary() {
  echo ""
  echo "================================"
  echo "Tests: $TESTS_RUN | Passed: $TESTS_PASSED | Failed: $TESTS_FAILED"
  echo "================================"
  [ "$TESTS_FAILED" -eq 0 ]
}
```

---

## 3. init-harness.sh 测试用例

### 3.1 测试清单

```
test-init.sh

describe "init on empty git repo"
  ├── it "creates AGENTS.md"
  ├── it "creates CLAUDE.md"
  ├── it "creates docs/ARCHITECTURE.md"
  ├── it "creates docs/CONVENTIONS.md"
  ├── it "creates docs/TESTING.md"
  ├── it "creates docs/SECURITY.md"
  ├── it "creates docs/design-docs/core-beliefs.md"
  ├── it "creates .github/PULL_REQUEST_TEMPLATE.md"
  ├── it "creates docs/exec-plans/active/ directory"
  ├── it "creates docs/exec-plans/completed/ directory"
  ├── it "creates docs/exec-plans/tech-debt/ directory"
  ├── it "creates docs/product-specs/ directory"
  ├── it "creates docs/references/ directory"
  ├── it "outputs valid JSON"
  ├── it "reports status as success"
  └── it "reports detected_stack as unknown"

describe "init with --project-name"
  ├── it "uses provided project name in AGENTS.md"
  └── it "reports correct project name in JSON"

describe "init with --description"
  └── it "uses provided description in AGENTS.md"

describe "init stack detection"
  ├── it "detects node (package.json)"
  ├── it "detects python (pyproject.toml)"
  ├── it "detects python (setup.py)"
  ├── it "detects go (go.mod)"
  ├── it "detects rust (Cargo.toml)"
  └── it "reports unknown when no markers found"

describe "init node stack fills correct commands"
  ├── it "AGENTS.md contains npm install"
  ├── it "AGENTS.md contains npm test"
  └── it "TESTING.md contains npm test"

describe "init idempotency"
  ├── it "does not overwrite existing AGENTS.md"
  ├── it "reports skipped files in JSON"
  └── it "creates only missing files"

describe "init with --force"
  ├── it "overwrites existing AGENTS.md"
  └── it "reports all files as created"

describe "init with --dry-run"
  ├── it "creates no files"
  ├── it "creates no directories"
  ├── it "outputs valid JSON"
  └── it "reports planned operations"

describe "init on non-git directory"
  ├── it "outputs warning about non-git"
  └── it "still creates all files"
```

### 3.2 关键测试实现示例

```bash
describe "init on empty git repo"

it "creates AGENTS.md"
  setup_test_dir
  output=$(bash "$SCRIPT_DIR/scripts/init-harness.sh" 2>&1)
  assert_file_exists "AGENTS.md"
  teardown_test_dir

it "outputs valid JSON"
  setup_test_dir
  output=$(bash "$SCRIPT_DIR/scripts/init-harness.sh" 2>&1)
  # 提取 JSON (跳过可能的 stderr 警告)
  json=$(echo "$output" | grep -E '^\{' | head -1)
  echo "$json" | jq . > /dev/null 2>&1
  assert_eq "0" "$?" "jq parse exit code"
  teardown_test_dir

it "reports detected_stack as unknown"
  setup_test_dir
  json=$(bash "$SCRIPT_DIR/scripts/init-harness.sh" 2>&1 | grep -E '^\{')
  assert_json_field "$json" ".detected_stack" "unknown"
  teardown_test_dir

describe "init stack detection"

it "detects node (package.json)"
  setup_test_dir
  echo '{"name":"test"}' > package.json
  json=$(bash "$SCRIPT_DIR/scripts/init-harness.sh" 2>&1 | grep -E '^\{')
  assert_json_field "$json" ".detected_stack" "node"
  teardown_test_dir

describe "init idempotency"

it "does not overwrite existing AGENTS.md"
  setup_test_dir
  echo "# My Custom Content" > AGENTS.md
  bash "$SCRIPT_DIR/scripts/init-harness.sh" > /dev/null 2>&1
  assert_file_contains "AGENTS.md" "My Custom Content"
  teardown_test_dir
```

---

## 4. audit-harness.sh 测试用例

### 4.1 测试清单

```
test-audit.sh

describe "audit on empty project"
  ├── it "outputs valid JSON"
  ├── it "reports overall_score as 0"
  ├── it "reports maturity_level as 0"
  ├── it "reports maturity_label as No Harness"
  └── it "generates priority_fixes"

describe "audit on Level 1 project (basic harness)"
  ├── it "scores entry_document > 0"
  ├── it "scores doc_structure > 0"
  ├── it "reports overall_score between 25-49"
  └── it "reports maturity_level as 1"

describe "audit on full harness project"
  ├── it "reports overall_score >= 80"
  ├── it "reports maturity_level >= 3"
  └── it "has minimal priority_fixes"

describe "audit entry_document scoring"
  ├── it "scores 0 when no AGENTS.md"
  ├── it "scores >= 40 when AGENTS.md exists"
  ├── it "scores higher when AGENTS.md < 100 lines"
  ├── it "scores lower when AGENTS.md > 100 lines"
  ├── it "bonus for quick commands section"
  ├── it "bonus for architecture section"
  └── it "bonus for constraints section"

describe "audit doc_structure scoring"
  ├── it "scores 0 when no docs/"
  ├── it "scores 25 per existing doc"
  └── it "scores less when doc is empty (< 5 lines)"

describe "audit doc_freshness scoring"
  ├── it "scores 100 when all docs fresh"
  ├── it "scores 50 when half docs stale"
  ├── it "scores 0 when all docs stale"
  └── it "scores 50 on non-git project"

describe "audit architecture_constraints scoring"
  ├── it "scores 0 with no linting"
  ├── it "scores +40 with lint script"
  ├── it "scores +20 with linter config"
  └── it "scores +20 with CI architecture check"

describe "audit test_coverage scoring"
  ├── it "scores +30 with test command in package.json"
  ├── it "scores +30 with tests/ directory"
  └── it "scores +20 with CI test step"

describe "audit automation scoring"
  ├── it "scores +50 with CI pipeline"
  ├── it "scores +30 with pre-commit hooks"
  └── it "scores +20 with PR template"

describe "audit exec_plans scoring"
  ├── it "scores 0 with no exec-plans/"
  ├── it "scores 40 with exec-plans/ dir"
  └── it "scores 100 with full structure and plan files"

describe "audit security_governance scoring"
  ├── it "scores +30 with .env in .gitignore"
  ├── it "scores +30 with SECURITY.md"
  └── it "scores +20 with CODEOWNERS"

describe "audit priority_fixes generation"
  ├── it "orders fixes by score ascending"
  ├── it "marks score < 50 as high impact"
  ├── it "marks score 50-74 as medium impact"
  ├── it "limits to 5 fixes maximum"
  └── it "each fix has action text"
```

### 4.2 关键测试实现示例

```bash
describe "audit on empty project"

it "reports overall_score as 0"
  setup_test_dir
  json=$(bash "$SCRIPT_DIR/scripts/audit-harness.sh" 2>&1)
  assert_json_field "$json" ".overall_score" "0"
  teardown_test_dir

describe "audit on full harness project"

it "reports overall_score >= 80"
  # 复制 full-harness fixture
  cp -r "$FIXTURES_DIR/full-harness" "$TEST_TMP/project"
  cd "$TEST_TMP/project"
  git init --quiet && git add -A && git commit -m "init" --quiet
  json=$(bash "$SCRIPT_DIR/scripts/audit-harness.sh" 2>&1)
  score=$(echo "$json" | jq '.overall_score')
  [ "$score" -ge 80 ]
  assert_eq "0" "$?" "score >= 80 (actual: $score)"
  teardown_test_dir
```

---

## 5. SKILL.md 规范测试

### 5.1 测试清单

```
test-skillmd.sh

describe "SKILL.md specification compliance"
  ├── it "has valid YAML frontmatter"
  ├── it "name field is lowercase with hyphens"
  ├── it "name field matches directory name"
  ├── it "name field has no consecutive hyphens"
  ├── it "name field does not start/end with hyphen"
  ├── it "name field is <= 64 characters"
  ├── it "description field is non-empty"
  ├── it "description field is <= 1024 characters"
  ├── it "body is under 500 lines"
  └── it "passes skills-ref validate (if available)"
```

### 5.2 实现

```bash
describe "SKILL.md specification compliance"

SKILLMD="$SCRIPT_DIR/SKILL.md"

it "name field is lowercase with hyphens"
  name=$(sed -n '/^---$/,/^---$/p' "$SKILLMD" | grep "^name:" | sed 's/name: *//')
  echo "$name" | grep -qE '^[a-z][a-z0-9]*(-[a-z0-9]+)*$'
  assert_eq "0" "$?" "name matches pattern"

it "body is under 500 lines"
  body_start=$(grep -n "^---$" "$SKILLMD" | tail -1 | cut -d: -f1)
  total_lines=$(wc -l < "$SKILLMD")
  body_lines=$((total_lines - body_start))
  [ "$body_lines" -lt 500 ]
  assert_eq "0" "$?" "body lines ($body_lines) < 500"
```

---

## 6. 跨平台测试矩阵

| 环境 | bash 版本 | git 版本 | 测试方式 |
|------|-----------|----------|----------|
| Ubuntu 22.04 | 5.1+ | 2.34+ | GitHub Actions |
| macOS 14 (Sonoma) | 3.2 (zsh default) + bash 5 | 2.39+ | 本地手动 |
| Alpine Linux | 5.2+ | 2.40+ | Docker |

### 6.1 已知 bash 兼容性注意事项

| 特性 | bash 3.2 (macOS 默认) | 处理方式 |
|------|------------------------|----------|
| `declare -A` (关联数组) | 不支持 | 不使用，改用位置参数 |
| `[[ ... ]]` | 支持 | 可使用 |
| `$((...))` | 支持 | 可使用 |
| Process substitution `<()` | 支持 | 可使用 |
| `readarray` / `mapfile` | 不支持 | 不使用，改用 while read |

---

## 7. 测试执行

### 7.1 运行所有测试

```bash
bash tests/run-tests.sh
```

### 7.2 运行单个测试套件

```bash
bash tests/test-init.sh
bash tests/test-audit.sh
bash tests/test-skillmd.sh
```

### 7.3 CI 集成

```yaml
# .github/workflows/test.yml
name: Tests
on: [push, pull_request]
jobs:
  test:
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - name: Run tests
        run: bash tests/run-tests.sh
      - name: Validate SKILL.md
        run: |
          npx skills-ref validate . || echo "skills-ref not available, skipping"
```

---

## 8. 验收标准追踪

| 验收标准 | 测试覆盖 | 状态 |
|----------|----------|------|
| SKILL.md 通过 skills-ref validate | test-skillmd.sh | 待实现 |
| npx skills add 安装成功 | 手动 E2E | 待实现 |
| 空仓库 init 生成完整结构 | test-init.sh "empty git repo" | 待实现 |
| init 不覆盖已有文件 | test-init.sh "idempotency" | 待实现 |
| --dry-run 不创建文件 | test-init.sh "dry-run" | 待实现 |
| --force 覆盖文件 | test-init.sh "force" | 待实现 |
| audit Level 0 输出 0 分 | test-audit.sh "empty project" | 待实现 |
| audit 完整项目 90+ 分 | test-audit.sh "full harness" | 待实现 |
| JSON 可被 jq 解析 | 所有 JSON 测试 | 待实现 |
| 每个缺陷有修复建议 | test-audit.sh "priority_fixes" | 待实现 |
| macOS + Linux 可运行 | CI 矩阵 | 待实现 |
| SKILL.md < 500 行 | test-skillmd.sh | 待实现 |
| 四种技术栈检测 | test-init.sh "stack detection" | 待实现 |
