# Raw Source: LLM Wiki

## 基本信息

- 标题：LLM Wiki
- 类型：文章
- 作者：未知
- 收集日期：2026-04-29
- 处理状态：已入库
- 主题标签：知识管理, AI, LLM, Wiki
- 可信度：中
- 重要性：5

## 一句话结论

LLM Wiki 是一种让 LLM 持续维护持久化知识库的模式，核心不是在查询时临时检索原始资料，而是把新资料和新问题不断整合进一个可演化的 Wiki。

## 核心观点

1. 传统 RAG 每次查询都要重新从原始资料中检索和拼装答案，知识不会自然累积。
2. LLM Wiki 把 LLM 的工作前移到 ingest 阶段，让 LLM 读资料、更新页面、建立关联、记录矛盾。
3. Wiki 是一个持久化、可复利的中间层，位于 raw sources 和用户查询之间。
4. 用户不主要负责写 Wiki，而是负责提供资料、提出问题、判断方向。
5. LLM 负责维护成本最高的部分：摘要、归档、交叉引用、一致性检查、更新日志。
6. Query 的答案如果有长期价值，也应该沉淀回 Wiki。
7. Lint 是系统健康检查，用于发现过期页面、孤立页面、缺少来源的结论、重复概念和新研究问题。

## 对 FlowUS 个人知识库的影响

这篇文章直接启发了当前系统的核心结构：

- `Raw Sources` 对应原始资料层。
- `Wiki Pages` 对应持久化综合层。
- `Questions` 对应查询与探索层。
- `Log` 对应演化时间线。
- `LLM 维护规则` 对应 schema / AGENTS.md。
- FlowUS MCP 让 LLM 可以直接维护 FlowUS，而不是通过本地 Markdown 中转。

## 新增或更新的 Wiki Pages

- LLM Wiki
- FlowUS 个人知识库 OS
- Raw Sources
- Wiki Pages
- Questions
- Outputs
- Log
- FlowUS MCP

## 争议 / 不确定性

- FlowUS MCP 的实际能力边界需要接入后验证，尤其是块级更新、关系字段写入、数据库查询过滤和页面搜索。
- FlowUS 作为云端系统，需要定期导出备份，避免长期知识资产被单一平台锁定。
- LLM 自动维护需要安全规则，尤其是稳定页面的大幅改写、页面合并和标签体系变更。

## 后续问题

- 什么样的资料值得进入 Raw Sources？
- 什么样的回答值得沉淀为 Wiki Page？
- 如何判断 Wiki Page 的成熟度？
- FlowUS MCP 是否支持足够稳定的关系字段写入？

