{
  "version": "1.0.0",
  "always_include": [
    "AGENTS.md",
    "CLAUDE.md",
    "GEMINI.md",
    "docs/project/核心信念.md",
    "docs/project/项目架构.md",
    "docs/project/开发规范.md",
    "docs/project/测试策略.md"
  ],
  "feature_required_docs": ["功能概览.md", "方案设计.md", "测试方案.md", "状态.md"],
  "change_type_context": {
    "api": ["docs/project/接口规范.md", "接口设计.md"],
    "db": ["docs/project/项目设计.md", "数据设计.md"],
    "rollout": [
      "docs/project/开发规范.md",
      "docs/project/运行基线.md",
      "docs/project/可观测性基线.md",
      "发布回滚.md"
    ]
  },
  "support_files": [
    ".harness/spec-policy.json",
    ".harness/doc-impact-rules.json",
    ".harness/context-policy.json",
    ".harness/run-policy.json"
  ],
  "max_context_files": 12
}
