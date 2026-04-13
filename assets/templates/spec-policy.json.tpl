{
  "template_pack": {
    "name": "{{TEMPLATE_PACK_NAME}}",
    "version": "{{TEMPLATE_VERSION}}",
    "profile": "{{TEMPLATE_PROFILE}}",
    "language": "{{TEMPLATE_LANGUAGE}}"
  },
  "quality_gate": {
    "strict_default": {{STRICT_DEFAULT}},
    "require_hydrated_doc_state": true,
    "placeholder_patterns": [
      "TODO:",
      "待补充",
      "在这里",
      "请补充",
      "是/否",
      "TBD",
      "FIXME",
      "PLACEHOLDER",
      "<待填写>",
      "<TODO>",
      "{{TODO}}",
      "暂无",
      "暂不填写",
      "略"
    ]
  },
  "project_docs": [
    {
      "id": "core-beliefs",
      "path": "harness/docs/project/核心信念.md",
      "required": true,
      "required_frontmatter": ["template_version", "template_profile", "template_language"],
      "required_sections": ["## 架构原则", "## 业务边界与领域模型", "## 技术选型", "## 一致性与数据原则", "## 接口与兼容性原则", "## 质量标准"]
    },
    {
      "id": "architecture",
      "path": "harness/docs/project/项目架构.md",
      "required": true,
      "required_frontmatter": ["template_version", "template_profile", "template_language"],
      "required_sections": ["## 系统上下文", "## 模块清单与职责", "## 分层与包结构", "## 核心链路与时序", "## 事务边界与一致性"]
    },
    {
      "id": "design",
      "path": "harness/docs/project/项目设计.md",
      "required": true,
      "required_frontmatter": ["template_version", "template_profile", "template_language"],
      "required_sections": ["## 设计目标", "## 工程设计结论", "## 分层设计约定", "## 当前代码挂点与职责分工", "## 异常、错误码与可恢复性设计"]
    },
    {
      "id": "api-spec",
      "path": "harness/docs/project/接口规范.md",
      "required": true,
      "required_frontmatter": ["template_version", "template_profile", "template_language"],
      "required_sections": ["## 协议与接口类型", "## 接口清单", "## 通用报文与上下文", "## 响应体与错误码规范", "## 典型示例与联调约定"]
    },
    {
      "id": "development",
      "path": "harness/docs/project/开发规范.md",
      "required": true,
      "required_frontmatter": ["template_version", "template_profile", "template_language"],
      "required_sections": ["## 技术栈开发约定", "## 新增功能最小落地清单", "## 编码规则", "## 评审要求", "## 分支与提交规范"]
    },
    {
      "id": "requirements",
      "path": "harness/docs/project/需求说明.md",
      "required": true,
      "required_frontmatter": ["template_version", "template_profile", "template_language"],
      "required_sections": ["## 产品背景与目标", "## 核心业务流程", "## 功能需求清单", "## 验收与成功指标"]
    },
    {
      "id": "testing",
      "path": "harness/docs/project/测试策略.md",
      "required": true,
      "required_frontmatter": ["template_version", "template_profile", "template_language"],
      "required_sections": ["## 测试目标", "## 测试分层矩阵", "## 关键链路测试设计", "## 发布与回归门禁"]
    },
    {
      "id": "security",
      "path": "harness/docs/project/安全规范.md",
      "required": true,
      "required_frontmatter": ["template_version", "template_profile", "template_language"],
      "required_sections": ["## 认证、授权与审计", "## 输入校验与反序列化安全", "## 敏感数据与日志脱敏", "## 安全评审触发条件"]
    }
  ],
  "feature_spec": {
    "base_dir": "harness/docs/features",
    "required_docs": ["功能概览.md", "方案设计.md", "测试方案.md", "状态.md"],
    "change_type_docs": {
      "api": ["接口设计.md"],
      "db": ["数据设计.md"],
      "rollout": ["发布回滚.md"]
    },
    "doc_rules": {
      "功能概览.md": {
        "required_frontmatter": ["template_version", "template_profile", "template_language"],
        "required_sections": ["## 业务背景与目标", "## 当前现状与边界", "## 上下游与依赖清单", "## 范围", "## 验收标准"]
      },
      "方案设计.md": {
        "required_frontmatter": ["template_version", "template_profile", "template_language"],
        "required_sections": ["## 变更摘要", "## 当前代码挂点与拟改动类", "## 模块与分层影响", "## 主链路时序与处理步骤", "## 事务、一致性与幂等", "## 实施顺序与最小改动集"]
      },
      "接口设计.md": {
        "required_frontmatter": ["template_version", "template_profile", "template_language"],
        "required_sections": ["## 接口清单", "## 接口详细设计", "## 请求设计", "## 响应与错误码", "## 典型示例与联调要点"]
      },
      "数据设计.md": {
        "required_frontmatter": ["template_version", "template_profile", "template_language"],
        "required_sections": ["## DDL 与结构变更", "## 表与索引设计", "## 数据迁移与回填", "## 回滚与验证"]
      },
      "测试方案.md": {
        "required_frontmatter": ["template_version", "template_profile", "template_language"],
        "required_sections": ["## 测试目标", "## 测试范围矩阵", "## 测试数据与环境准备", "## 关键测试用例", "## 回归命令与证据"]
      },
      "发布回滚.md": {
        "required_frontmatter": ["template_version", "template_profile", "template_language"],
        "required_sections": ["## 发布目标与策略", "## 发布前检查", "## 发布后观测指标", "## 回滚触发条件"]
      },
      "状态.md": {
        "required_frontmatter": ["template_version", "template_profile", "template_language"],
        "required_sections": ["## 当前状态", "## 本轮实现与剩余项", "## 当前阶段检查项", "## 阻塞与风险"]
      }
    }
  }
}
