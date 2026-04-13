{
  "version": "1.0.0",
  "language": "{{TEMPLATE_LANGUAGE}}",
  "template_profile": "{{TEMPLATE_PROFILE}}",
  "rules": [
    {
      "id": "java-api-surface",
      "description": "Java Controller、OpenAPI 或客户端接口变更时，必须同步接口文档。",
      "guidance": "至少更新 harness/docs/project/接口规范.md 或对应功能目录下的 接口设计.md。",
      "code_patterns": [
        "^src/main/java/.*/controller/.*\\.java$",
        "^src/main/java/.*/api/.*\\.java$",
        "^src/main/java/.*/client/.*\\.java$",
        "^src/main/java/.*/openapi/.*\\.java$",
        "^src/main/resources/openapi/.*\\.(yaml|yml|json)$"
      ],
      "required_doc_patterns_any": [
        "^harness/docs/project/接口规范\\.md$",
        "^harness/docs/features/[^/]+/接口设计\\.md$"
      ]
    },
    {
      "id": "java-db-change",
      "description": "数据库结构、迁移脚本或 Mapper 变更时，必须同步数据库文档。",
      "guidance": "至少更新对应功能目录下的 数据设计.md；如果属于跨功能的共享约束，补充项目级 项目设计.md。",
      "code_patterns": [
        "^src/main/resources/db/migration/.*$",
        "^src/main/resources/db/changelog/.*$",
        "^src/main/resources/mapper/.*\\.(xml|sql)$",
        "^db/.*\\.(sql|ddl)$"
      ],
      "required_doc_patterns_any": [
        "^harness/docs/features/[^/]+/数据设计\\.md$",
        "^harness/docs/project/项目设计\\.md$"
      ]
    },
    {
      "id": "java-security-change",
      "description": "认证、授权、安全配置变更时，必须同步安全文档。",
      "guidance": "至少更新 harness/docs/project/安全规范.md；如果只影响某个功能，也可以同时补充对应功能设计文档。",
      "code_patterns": [
        "^src/main/java/.*/security/.*\\.java$",
        "^src/main/java/.*/auth/.*\\.java$",
        "^src/main/java/.*/config/.*Security.*\\.java$",
        "^src/main/resources/security/.*$"
      ],
      "required_doc_patterns_any": [
        "^harness/docs/project/安全规范\\.md$",
        "^harness/docs/features/[^/]+/方案设计\\.md$"
      ]
    },
    {
      "id": "build-or-rollout-change",
      "description": "构建、配置、部署相关变更时，必须同步开发或发布文档。",
      "guidance": "至少更新 harness/docs/project/开发规范.md，或对应功能目录下的 发布回滚.md。",
      "code_patterns": [
        "^pom\\.xml$",
        "^build\\.gradle$",
        "^build\\.gradle\\.kts$",
        "^src/main/resources/application.*\\.(yaml|yml|properties)$",
        "^src/main/resources/bootstrap.*\\.(yaml|yml|properties)$",
        "^Dockerfile$",
        "^helm/.*$",
        "^k8s/.*$",
        "^deploy/.*$"
      ],
      "required_doc_patterns_any": [
        "^harness/docs/project/开发规范\\.md$",
        "^harness/docs/features/[^/]+/发布回滚\\.md$"
      ]
    },
    {
      "id": "architecture-rule-change",
      "description": "架构边界规则或分层约束变更时，必须同步架构文档。",
      "guidance": "至少更新 harness/docs/project/项目架构.md；必要时补充对应功能设计文档。",
      "code_patterns": [
        "^harness/.harness/architecture\\.json$",
        "^scripts/lint-architecture\\.sh$"
      ],
      "required_doc_patterns_any": [
        "^harness/docs/project/项目架构\\.md$",
        "^harness/docs/features/[^/]+/方案设计\\.md$"
      ]
    }
  ]
}
