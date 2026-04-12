# harness-engineering

一个面向 AI 编码代理的 Agent Skill，用来初始化、审计和维护
Harness Engineering 工作环境，并为项目级与功能级 spec 提供统一模板。

## 运行前提

- 需要 `bash`、`git`、`jq`
- 建议第一次在新机器使用前先执行 `bash scripts/check-runtime-deps.sh --json`
- Windows 环境推荐使用 WSL2；当前仓库默认按 POSIX Shell 语义维护

## 安装

本地开发和试点时，推荐直接使用仓库自带的 runtime-only 安装脚本：

```bash
bash scripts/install-skill.sh --global
```

这个安装脚本会先执行 `check-runtime-deps.sh`，缺少 `bash` / `git` / `jq` 时会直接失败。

它会先导出一个 runtime-only Skill 包，再安装到全局目录。安装包会保留运行时真正需要的 `SKILL.md`、核心脚本、`scripts/lib/`、`assets/templates/`、`assets/hooks/`、`assets/ci-templates/`、`references/` 和 `LICENSE`，不会把 `doc/`、`README.md`、`CHANGELOG.md`、测试和发布脚本一起装进 `~/.agents/skills/`。
导出的 runtime-only 包现在也会包含 `scripts/check-runtime-deps.sh` 和 `schemas/plan-machine.schema.json`，方便安装后直接做依赖自检和 machine plan 校验。

如果你是从远程仓库直接安装：

```bash
npx skills add 3202336152/harness-engineering
```

## 主要命令

| 命令 | 说明 |
|------|------|
| `/harness init` | 初始化项目的 Harness 基础结构 |
| `/harness audit` | 审计当前项目的 Harness 成熟度 |
| `/harness plan` | 生成结构化执行计划 |

详细参数、返回结果、产物和示例，请看 [doc/命令使用说明.md](./doc/命令使用说明.md)。

## 基础自治入口

| 命令 | 说明 |
|------|------|
| `bash scripts/harness-exec.sh prepare --task "<任务>" --feature-id FEAT-001 --title "<标题>" --json` | 一次生成功能 spec、Markdown 执行计划、机器计划 JSON、上下文 bundle |
| `bash scripts/harness-exec.sh verify --feature-id FEAT-001 --json` | 聚合校验，并落 run record、metrics ledger、task memory、progress、evidence |
| `bash scripts/harness-exec.sh run --task "<任务>" --feature-id FEAT-001 --title "<标题>" --json` | 串联 `prepare -> verify -> autofix-safe -> reverify`，并按策略触发证据采集与 GC |
| `bash scripts/harness-exec.sh restore --feature-id FEAT-001 --json` | 从 `.harness/runtime/` 恢复最近任务状态、待办检查项和推荐上下文 |

重复执行语义：

- `prepare` 会刷新当前任务对应的 spec 骨架、执行计划和上下文 bundle，适合在任务范围变化后重跑。
- `verify` 和 `run` 会追加新的运行记录，并更新最新 task-memory / progress 快照，适合在实现推进过程中反复执行。
- 如果目标是升级模板或迁移历史文档，优先使用 `migrate-template-docs.sh`，不要把 `harness-exec` 当成文档重写器。

## 仓库内容

- `SKILL.md`：Skill 入口文件
- `scripts/`：脚本实现
- `assets/templates/`：初始化模板
- `assets/hooks/`：本地提交流程模板
- `assets/ci-templates/`：CI 门禁模板
- `references/`：深度参考文档
- `scripts/export-skill-package.sh`：导出 runtime-only 安装包
- `scripts/install-skill.sh`：一键导出并安装 runtime-only 包
- `tests/`：本地测试

## Spec 工作流

- 项目级 spec 统一放在 `docs/project/`
- 功能级 spec 统一放在 `docs/features/<feature-id>-<title-slug>/`
- 执行计划、产品需求沉淀、外部参考资料等运行期支撑内容统一放在 `.harness/` 下，避免和共享真相文档混在一起
- `doc/` 下的维护文档统一使用中文文件名
- 项目级与功能级 spec 模板默认生成中文内容和中文 `md` 文件名，便于团队查看、评审和检索
- 默认生成的文件示例：
  - `docs/project/核心信念.md`
  - `docs/project/项目架构.md`
  - `docs/project/开发规范.md`
  - `docs/project/运行基线.md`
  - `docs/features/FEAT-001-order-query/功能概览.md`
  - `docs/features/FEAT-001-order-query/接口设计.md`
- 生成的项目级/功能级 spec 会带 `template_version`、`template_profile`、`template_language` 元数据
- `init` 还会生成 `docs/project/运行基线.md`、`docs/project/可观测性基线.md`、`.harness/context-policy.json`、`.harness/run-policy.json`
- `init` 会创建 `.harness/exec-plans/`、`.harness/product-specs/`、`.harness/references/`，用于承接执行计划和辅助上下文资料
- 项目规则通过 `.harness/spec-policy.json` 描述
- 功能文档通过 `bash scripts/new-feature-spec.sh ...` 生成，并附带 `manifest.json`
- 执行计划通过 `bash scripts/plan-harness.sh ...` 同时生成 `md + json`
- machine plan JSON 的正式 schema 位于 `schemas/plan-machine.schema.json`
- 真正开始一个功能开发时，优先使用 `bash scripts/harness-exec.sh prepare ...` 或 `bash scripts/new-feature-spec.sh ...` 补齐 spec；`/harness plan` 更适合作为执行计划记录，不应成为唯一前置入口
- 任务上下文通过 `bash scripts/resolve-task-context.sh --task ... --json` 解析并可落盘为 bundle
- 代码改动与文档更新的一致性可通过 `bash scripts/check-doc-impact.sh --json --staged` 进行门禁
- 结构完整性通过 `bash scripts/validate-spec.sh --json` 校验
- 内容质量门禁可通过 `bash scripts/validate-spec.sh --json --strict` 启用
- 安全可自动修复的结构问题可通过 `bash scripts/validate-spec.sh --json --autofix-safe` 修复
- 高风险功能可通过 `bash scripts/check-rollback-readiness.sh --feature-id FEAT-001 --json` 校验回滚准备度
- 模板升级后的历史文档可通过 `bash scripts/migrate-template-docs.sh --json` 做带备份的安全迁移
- 运行期证据采集策略可通过 `.harness/observability-policy.json` 配置
- 运行记录会沉淀到 `.harness/runs/`、`.harness/metrics/`、`.harness/evidence/`、`.harness/runtime/`
- 审计结果会在已初始化项目中刷新 `.harness/runtime/last-audit.json`，便于 AI 判断是否长期未做健康检查
- 旧的上下文 bundle、run record、evidence 目录可通过 `bash scripts/harness-gc.sh --json` 做保留清理

### 初始化后的第二阶段

- `init` 只负责生成规范骨架和策略文件，不会语义理解整个仓库，也不会自动把项目真实信息补进 `docs/project/`
- 新生成的项目级/功能级文档默认带 `doc_state: scaffold`，表示它们只是骨架，不能直接当作项目真相源
- 对 Java 项目，更可靠的做法是先运行 `bash scripts/scan-java-project.sh --json`，把 `.harness/runtime/java-doc-scan.json` 作为全量扫描基线
- 然后让宿主模型基于扫描清单做关键深读，再补全项目级文档
- 推荐关键深读清单：`pom.xml` / `build.gradle*`、启动类或主入口、`src/main/java` 前两层包结构、主要 `Controller` / `Facade` / `Listener` / `Job`、核心 `ApplicationService` / `DomainService`、`application.yml` / `application-*.yml`
- 这里不要求把所有源码全文一次性塞进上下文，但必须先完成全量扫描，再覆盖代表性入口、核心链路、关键配置和主要外部集成
- 补全并核实真实内容后，把对应文档 frontmatter 中的 `doc_state` 从 `scaffold` 改成 `hydrated`
- 如果仍有未确认信息，直接在文档中写“待确认 / 未覆盖范围”，不要凭空补全；完成后运行 `bash scripts/validate-spec.sh --json --strict`
- 对 Java profile，生成的 `.harness/spec-policy.json` 会默认启用 `strict_default: true`，因此 `validate-spec --json` 就会按 strict 门禁检查 `doc_state` 和 Java 扫描覆盖
- `init` 的 JSON 输出会包含 `hydration_required_count` 与 `hydration_required_docs`，可直接拿来追踪哪些项目文档还停留在骨架状态

## 强约束模式

- 默认的 `init` 只负责把规范、目录和策略文件搭起来，不会默认改你的 Git hook、Husky 或 CI 配置
- 如果你希望把“文档影响检查 + spec 校验 + 架构 lint”接成真实门禁，需要在初始化时显式打开约束选项
- 对个人 Java 项目，推荐直接使用 `--with-strong-constraints`，让 AI 入口约束、提交前检查和 CI 校验形成闭环，而不是依赖“记得手动跑命令”

常见用法：

```bash
bash scripts/init-harness.sh --with-strong-constraints
bash scripts/init-harness.sh --with-git-hook --with-strict-spec-checks
bash scripts/init-harness.sh --with-git-hook
bash scripts/init-harness.sh --with-husky
bash scripts/init-harness.sh --with-github-actions
```

说明：

- `--with-strong-constraints` 会组合启用 `--with-git-hook`、`--with-github-actions`，并让生成的本地 hook 使用 `validate-spec --strict`
- `--with-git-hook` 会生成 `.git/hooks/pre-commit`
- `--with-strict-spec-checks` 可与 `--with-git-hook` 或 `--with-husky` 组合使用，让本地 hook 直接运行 `validate-spec --json --strict`
- 对 Java 画像，只要启用了 `--with-git-hook` 或 `--with-husky`，`init` 会自动把本地 spec 校验提升为 strict，避免骨架文档在提交时漏网
- `--with-husky` 会生成 `.husky/pre-commit`，并把仓库的 `core.hooksPath` 设置为 `.husky`
- `--with-github-actions` 会生成 `.github/workflows/harness-guardrails.yml`
- 开启任一约束选项时，会把 Skill 运行时能力 vendoring 到 `.harness/skill-runtime/harness-engineering`
- 这样生成出来的 hook 和 CI 会固定引用仓库内的 vendored runtime，而不是依赖每台机器都提前装好 `~/.agents/skills/harness-engineering`
- 需要把 `.harness/skill-runtime/harness-engineering` 一起提交到仓库，CI 才能稳定复用同一套校验脚本

## 当前自治能力边界

已经补齐的基础能力：

- 机械化约束：`check-doc-impact`、`validate-spec`、`lint-architecture`、`check-rollback-readiness` 都可以直接接本地钩子和 CI
- 上下文分级：`.harness/context-policy.json` + `resolve-task-context.sh` 会把必读规范、功能 spec、验证步骤收敛成机器可读 bundle
- 文档熵控制：`manifest.json`、模板元数据、严格校验、template drift 检查、safe autofix 已经形成基础治理面
- 历史模板迁移：`migrate-template-docs.sh` 会先备份，再调用 safe autofix 迁移结构类模板差异
- 反馈闭环：`harness-exec.sh verify/run` 会聚合校验结果，并把 run record、metrics、task memory、progress、evidence 一起落盘
- 长周期记忆：`.harness/runtime/task-memory.json` 与 `.harness/runtime/progress.md` 会持续记录最近任务和运行状态
- 审计记忆：`.harness/runtime/last-audit.json` 会记录最近一次成熟度检查的时间与摘要，方便入口文档触发周期性 audit
- 会话恢复：`harness-exec.sh restore` 可以在上下文压缩或切换会话后重建最近任务摘要与必读上下文
- 可观测性接入：`.harness/observability-policy.json` 可以按项目配置命令输出和文件证据采集
- 回收治理：`harness-gc.sh` 会按 `.harness/run-policy.json` 的保留策略清理旧上下文、旧记录、旧证据

还没有完全自动化的部分：

- 历史文档迁移目前是“安全结构迁移”，不是“理解语义后自动重写全文”
- 运行账本和证据目前是仓库本地文件形态，还没有内建 dashboard、远端聚合或告警平台自动注册
- `autofix-safe` 目前只覆盖 spec 结构和少量元数据修复，不会自动改业务代码或补全业务语义内容

## Java Profile

- Java 项目默认会落到 `java-backend-service` profile
- 可以在初始化时通过 `--profile java-batch-job`、`--profile java-adapter` 等方式覆盖
- `profile` 会写入 `.harness/spec-policy.json`，后续功能级 spec 会继承这一画像
- 推荐把 `profile` 当作“模板画像”，而不是硬编码的技术判断，后续可以按部门场景继续扩展

## 模板定制

- 默认模板位于 `assets/templates/`
- 项目级持久覆写目录为 `.harness/templates/`
- 用户级个性化覆写可通过环境变量 `HARNESS_TEMPLATE_ROOT=/path/to/templates` 指定
- 单次运行也可通过 `--template-root <path>` 指定模板根目录
- 模板查找优先级：`--template-root` / `HARNESS_TEMPLATE_ROOT` > `.harness/templates/` > 内置默认模板
- 可以先用 `bash scripts/prepare-template-overrides.sh --list` 查看当前内置模板清单
- 可以先用 `bash scripts/prepare-template-overrides.sh --template feature/overview.md.tpl` 导出默认模板，再按团队需要修改

## 模板治理

- `bash scripts/check-template-drift.sh --json` 可以检查项目级/功能级 spec 的模板元数据是否和 `.harness/spec-policy.json` 一致
- 该脚本也会检查 `.harness/templates/` 与 `HARNESS_TEMPLATE_ROOT` 下的 override：
  - 与内置模板完全一致的 override，会被识别为冗余覆盖
  - 无法映射到内置模板的 override，会被识别为孤儿模板
  - 与内置模板不同的 override，会被识别为自定义模板
- 适合在模板升级、团队推广、或者项目引入个性化模板后做一次审计

## 文档门禁

- `init` 会生成 `.harness/doc-impact-rules.json`，用于定义“哪些代码改动必须同步哪些文档”
- `bash scripts/check-doc-impact.sh --json --staged` 适合本地提交前检查
- `bash scripts/check-doc-impact.sh --json --base-ref <sha> --head-ref <sha>` 适合接到 PR / MR CI
- 默认内置了一组偏 Java 项目的规则：
  - Controller / OpenAPI / client 变更要求更新接口文档
  - 数据库迁移和 SQL 变更要求更新数据库文档
  - 安全相关变更要求更新安全文档
  - 构建、配置、部署变更要求更新开发或发布文档
- 本地钩子示例位于 `assets/hooks/pre-commit-doc-guard.sh.tpl`
- GitHub Actions 模板位于 `assets/ci-templates/github-actions.yml.tpl`

## 本地验证

```bash
bash tests/run-tests.sh
bash scripts/check-runtime-deps.sh --json
bash scripts/verify-spec-compliance.sh
bash scripts/export-skill-package.sh --output-dir .build/skill-package
bash scripts/publish-check.sh --skip-official
```

如果你想在 GitHub 上跑带官方安装/校验链路的发布检查，现在可以手动触发 `Publish Check` workflow。

## 相关说明

如果你是这个仓库的维护者，建议先看：

- [doc/文档导航.md](./doc/文档导航.md)
- [doc/本地使用指南.md](./doc/本地使用指南.md)
- [doc/命令使用说明.md](./doc/命令使用说明.md)
- [doc/能力与功能说明.md](./doc/能力与功能说明.md)
- [doc/安装与试点指南.md](./doc/安装与试点指南.md)
- [references/MATURITY-MODEL.md](./references/MATURITY-MODEL.md)

## License

MIT
