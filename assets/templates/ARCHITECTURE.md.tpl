# 架构说明

兼容旧版 harness 流程的入口文档。

当前项目级架构规范的主入口位于 `docs/project/项目架构.md`。

## 分层模型

建议依赖方向：

```text
Types -> Config -> Repo -> Service -> Runtime -> UI
```
