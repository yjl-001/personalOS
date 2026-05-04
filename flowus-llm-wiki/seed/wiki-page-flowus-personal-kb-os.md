# FlowUS 个人知识库 OS

## 当前理解

FlowUS 个人知识库 OS 是把 FlowUS 作为知识库本体、LLM Agent 作为维护者、FlowUS MCP 作为读写通道的一套个人知识管理系统。

它不把 FlowUS 当成普通笔记夹，而是当成一个结构化数据库和 Wiki 的组合。Raw Sources 保存原始资料，Wiki Pages 保存持续更新的综合理解，Questions 驱动知识库生长，Outputs 保存最终成果，Log 记录演化过程。

有 FlowUS MCP 后，系统可以比“本地 Markdown + 手动同步 FlowUS”的方案更简洁：Agent 直接读写 FlowUS 页面、数据库和关系字段，FlowUS 同时承担展示层和存储层。

## 核心要点

- FlowUS 是 canonical knowledge base。
- Agent 通过 MCP 维护数据库和页面。
- 本地文件只保存蓝图、模板和 Agent 规则。
- 先用 5 个核心数据库跑通闭环，不提前拆 Projects、Areas、Reviews。
- 大规模修改需要先预览，小规模更新可以直接执行。
- 需要定期导出 FlowUS 备份，降低平台锁定风险。

## 系统模块

- Raw Sources：原始资料层。
- Wiki Pages：知识综合层。
- Questions：问题驱动层。
- Outputs：成果输出层。
- Log：演化记录层。
- Dashboard：日常入口。
- LLM 维护规则：Agent 操作协议。

## 主要来源

- Raw Source: LLM Wiki
- 当前 FlowUS 系统设计讨论

## 支持证据

- FlowUS 的多维表、页面、关系字段和视图适合承载结构化知识库。
- MCP 让 Agent 可以直接维护 FlowUS，减少人工复制粘贴。
- LLM Wiki 的三层结构可以自然映射到 FlowUS 数据库。

## 反对证据 / 争议

- FlowUS MCP 能力需要实际连接后验证。
- FlowUS 页面不是本地 Markdown 文件，版本控制和批量 diff 不如 Git 直接。
- 复杂关系字段可能增加初始搭建成本。

## 与我的关系

这是当前个人知识库的目标架构。第一版应该追求简洁、可用和可维护，而不是一开始做成大型系统。

## 可应用场景

- 日常资料收集与整理
- 主题研究
- 长期自我复盘
- 写作输出
- 项目知识管理
- 决策记录

## 未解决问题

- FlowUS MCP 是否支持稳定的字段 ID 映射？
- 是否需要为本地备份增加定期导出流程？
- 一周使用后是否需要拆出 Projects 或 Areas？

## 更新记录

- 2026-04-29：创建首版系统主题页。

