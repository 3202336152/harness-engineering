# harness-engineering

一个面向 AI 编码代理的 Agent Skill，用来初始化、审计和维护
Harness Engineering 工作环境，并为项目级与功能级 spec 提供统一模板。

## 安装

```bash
npx skills add 3202336152/harness-engineering
```

## 主要命令

| 命令 | 说明 |
|------|------|
| `/harness init` | 初始化项目的 Harness 基础结构 |
| `/harness audit` | 审计当前项目的 Harness 成熟度 |
| `/harness plan` | 生成结构化执行计划 |

## 仓库内容

- `SKILL.md`：Skill 入口文件
- `scripts/`：脚本实现
- `assets/templates/`：初始化模板
- `references/`：深度参考文档
- `tests/`：本地测试

## Spec 工作流

- 项目级 spec 统一放在 `docs/project/`
- 功能级 spec 统一放在 `docs/features/<feature-id>-<title-slug>/`
- `doc/` 下的维护文档统一使用中文文件名
- 项目级与功能级 spec 模板默认生成中文内容，便于团队查看、评审和比对
- 生成的项目级/功能级 spec 会带 `template_version`、`template_profile`、`template_language` 元数据
- 项目规则通过 `.harness/spec-policy.json` 描述
- 功能文档通过 `bash scripts/new-feature-spec.sh ...` 生成
- 代码改动与文档更新的一致性可通过 `bash scripts/check-doc-impact.sh --json --staged` 进行门禁
- 结构完整性通过 `bash scripts/validate-spec.sh --json` 校验
- 内容质量门禁可通过 `bash scripts/validate-spec.sh --json --strict` 启用
- 兼容脚本与 CI 的前提下，`docs/project/*.md` 与 `docs/features/*/*.md` 保持稳定路径命名

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

## 本地验证

```bash
bash tests/run-tests.sh
bash scripts/publish-check.sh --skip-official
```

## 相关说明

如果你是这个仓库的维护者，建议先看：

- [doc/文档导航.md](./doc/文档导航.md)
- [doc/本地使用指南.md](./doc/本地使用指南.md)

## License

MIT
