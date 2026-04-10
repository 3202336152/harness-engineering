{
  "template_pack": {
    "name": "{{TEMPLATE_PACK_NAME}}",
    "version": "{{TEMPLATE_VERSION}}",
    "profile": "{{TEMPLATE_PROFILE}}",
    "language": "{{TEMPLATE_LANGUAGE}}"
  },
  "quality_gate": {
    "strict_default": false,
    "placeholder_patterns": ["TODO:", "待补充", "在这里", "请补充", "是/否"]
  },
  "project_docs": [
    {
      "id": "architecture",
      "path": "docs/project/项目架构.md",
      "required": true,
      "required_frontmatter": ["template_version", "template_profile", "template_language"],
      "required_sections": ["## 系统上下文", "## 分层与包结构", "## 事务边界与一致性"]
    },
    {
      "id": "design",
      "path": "docs/project/项目设计.md",
      "required": true,
      "required_frontmatter": ["template_version", "template_profile", "template_language"],
      "required_sections": ["## 设计目标", "## Java 分层设计约定", "## 异常、错误码与可恢复性设计"]
    },
    {
      "id": "api-spec",
      "path": "docs/project/接口规范.md",
      "required": true,
      "required_frontmatter": ["template_version", "template_profile", "template_language"],
      "required_sections": ["## 协议与接口类型", "## 接口清单", "## 响应体与错误码规范"]
    },
    {
      "id": "development",
      "path": "docs/project/开发规范.md",
      "required": true,
      "required_frontmatter": ["template_version", "template_profile", "template_language"],
      "required_sections": ["## Java 开发约定", "## 编码规则", "## 评审要求"]
    },
    {
      "id": "requirements",
      "path": "docs/project/需求说明.md",
      "required": true,
      "required_frontmatter": ["template_version", "template_profile", "template_language"],
      "required_sections": ["## 产品背景与目标", "## 功能需求清单", "## 验收与成功指标"]
    },
    {
      "id": "testing",
      "path": "docs/project/测试策略.md",
      "required": true,
      "required_frontmatter": ["template_version", "template_profile", "template_language"],
      "required_sections": ["## 测试目标", "## 测试分层矩阵", "## 发布与回归门禁"]
    },
    {
      "id": "security",
      "path": "docs/project/安全规范.md",
      "required": true,
      "required_frontmatter": ["template_version", "template_profile", "template_language"],
      "required_sections": ["## 认证、授权与审计", "## 输入校验与反序列化安全", "## 安全评审触发条件"]
    }
  ],
  "feature_spec": {
    "base_dir": "docs/features",
    "required_docs": ["功能概览.md", "方案设计.md", "测试方案.md", "状态.md"],
    "change_type_docs": {
      "api": ["接口设计.md"],
      "db": ["数据设计.md"],
      "rollout": ["发布回滚.md"]
    },
    "doc_rules": {
      "功能概览.md": {
        "required_frontmatter": ["template_version", "template_profile", "template_language"],
        "required_sections": ["## 业务背景与目标", "## 范围", "## 验收标准"]
      },
      "方案设计.md": {
        "required_frontmatter": ["template_version", "template_profile", "template_language"],
        "required_sections": ["## 变更摘要", "## 模块与分层影响", "## 事务、一致性与幂等"]
      },
      "接口设计.md": {
        "required_frontmatter": ["template_version", "template_profile", "template_language"],
        "required_sections": ["## 接口清单", "## 请求设计", "## 响应与错误码"]
      },
      "数据设计.md": {
        "required_frontmatter": ["template_version", "template_profile", "template_language"],
        "required_sections": ["## DDL 与结构变更", "## 数据迁移与回填", "## 回滚与验证"]
      },
      "测试方案.md": {
        "required_frontmatter": ["template_version", "template_profile", "template_language"],
        "required_sections": ["## 测试目标", "## 测试范围矩阵", "## 关键测试用例"]
      },
      "发布回滚.md": {
        "required_frontmatter": ["template_version", "template_profile", "template_language"],
        "required_sections": ["## 发布目标与策略", "## 发布前检查", "## 回滚触发条件"]
      },
      "状态.md": {
        "required_frontmatter": ["template_version", "template_profile", "template_language"],
        "required_sections": ["## 当前状态", "## 当前阶段检查项", "## 阻塞与风险"]
      }
    }
  }
}
