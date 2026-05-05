# FlowUS LLM Wiki Schema

This document defines the core database contract to create in FlowUS. The field names should stay stable, because agents will use these names during MCP reads and writes.

## Relation Map

```text
Raw Sources -> Wiki Pages
Raw Sources -> Questions
Wiki Pages  -> Wiki Pages
Wiki Pages  -> Questions
Questions   -> Outputs
Outputs     -> Raw Sources / Wiki Pages / Questions
Log         -> Raw Sources / Wiki Pages / Questions / Outputs
```

## 01 Raw Sources

Purpose:

Store immutable source material plus processing state.

Recommended database name: `Raw Sources`

| Field name | Type | Required | Notes |
|---|---|---:|---|
| 标题 | title | yes | source title |
| 类型 | select | yes | 文章 / 书 / 视频 / 播客 / 论文 / 网页 / 对话 / 日记 / 图片 / 其他 |
| 来源链接 | url | no | original source link |
| 作者 | rich_text | no | author, institution, or speaker |
| 收集日期 | date | yes | when the source entered the system |
| 处理状态 | select | yes | 未处理 / 阅读中 / 已摘要 / 已入库 / 待复查 / 已归档 |
| 主题标签 | multi_select | no | AI, knowledge management, health, writing, etc. |
| 可信度 | select | no | 高 / 中 / 低 / 未评估 |
| 重要性 | number | no | 1-5, where 5 is highest importance |
| 摘要 | rich_text | no | LLM-generated summary |
| 关键摘录 | rich_text | no | key quotations, timestamps, or excerpts |
| 关联 Wiki Pages | relation | no | links to `Wiki Pages` |
| 关联 Questions | relation | no | links to `Questions` |
| 处理记录 | rich_text | no | how the agent processed this source |
| 最后处理时间 | date | no | latest ingest time |

Suggested views:

- `未处理`: `处理状态 = 未处理`, sorted by `收集日期` ascending
- `高价值`: `重要性 >= 4`
- `待复查`: `处理状态 = 待复查`
- `按类型`: grouped by `类型`
- `按主题`: grouped by `主题标签`

## 02 Wiki Pages

Purpose:

Store concept pages, topic pages, person pages, method pages, case pages, and self-knowledge pages.

Recommended database name: `Wiki Pages`

| Field name | Type | Required | Notes |
|---|---|---:|---|
| 页面名称 | title | yes | page title |
| 页面类型 | select | yes | 概念 / 主题 / 人物 / 方法 / 案例 / 自我知识 / 决策 / 时间线 / 索引 |
| 一句话摘要 | rich_text | yes | one-line summary |
| 成熟度 | select | yes | 草稿 / 初步成型 / 稳定 / 待重写 / 已废弃 |
| 可信度 | select | yes | 高 / 中 / 低 / 混合 / 待验证 |
| 领域 | multi_select | no | long-term domains |
| 主题标签 | multi_select | no | finer-grained tags |
| 相关资料 | relation | no | links to `Raw Sources` |
| 相关问题 | relation | no | links to `Questions` |
| 相关页面 | relation | no | self-relation to `Wiki Pages` |
| 最后更新 | date | yes | latest content update |
| 推荐复查时间 | date | no | next review date |
| 待验证点 | rich_text | no | claims needing evidence or review |
| 更新摘要 | rich_text | no | what changed in the latest update |

Suggested views:

- `全部知识页`: default table
- `概念地图`: `页面类型 = 概念`
- `主题页`: `页面类型 = 主题`
- `自我知识`: `页面类型 = 自我知识`
- `待重写`: `成熟度 = 待重写`
- `待验证`: `可信度 = 待验证` or `待验证点` not empty
- `近期更新`: sorted by `最后更新` descending
- `稳定知识`: `成熟度 = 稳定`

## 03 Questions

Purpose:

Store high-value questions. The knowledge base should grow around questions, not around collections.

Recommended database name: `Questions`

| Field name | Type | Required | Notes |
|---|---|---:|---|
| 问题 | title | yes | the question itself |
| 状态 | select | yes | 未开始 / 探索中 / 已回答 / 持续更新 / 暂停 |
| 问题类型 | select | yes | 研究 / 决策 / 自我理解 / 写作 / 项目 / 复盘 |
| 优先级 | select | no | 低 / 中 / 高 |
| 当前答案 | rich_text | no | current synthesized answer |
| 相关资料 | relation | no | links to `Raw Sources` |
| 相关知识页 | relation | no | links to `Wiki Pages` |
| 输出成果 | relation | no | links to `Outputs` |
| 下一个问题 | rich_text | no | next question to explore |
| 是否沉淀为 Wiki | checkbox | no | whether it has already been written back into Wiki Pages |
| 创建日期 | date | yes | creation date |
| 最后更新 | date | no | latest answer or update |

Suggested views:

- `正在探索`: `状态 = 探索中` or `持续更新`
- `高优先级`: `优先级 = 高`
- `待沉淀`: `是否沉淀为 Wiki = false` and `当前答案` not empty
- `已回答`: `状态 = 已回答`

## 04 Outputs

Purpose:

Store deliverables generated from the knowledge base.

Recommended database name: `Outputs`

| Field name | Type | Required | Notes |
|---|---|---:|---|
| 标题 | title | yes | output title |
| 类型 | select | yes | 文章 / Memo / PPT / 清单 / 方案 / 课程 / 图表 / 对话总结 |
| 状态 | select | yes | 草稿 / 修改中 / 已完成 / 已发布 / 已归档 |
| 来源问题 | relation | no | links to `Questions` |
| 来源知识页 | relation | no | links to `Wiki Pages` |
| 来源资料 | relation | no | links to `Raw Sources` |
| 发布位置 | url | no | external publishing URL |
| 创建日期 | date | yes | creation date |
| 最后更新 | date | no | latest update |
| 下一步动作 | rich_text | no | revise, publish, or review next |

Suggested views:

- `草稿`: `状态 = 草稿` or `修改中`
- `已完成`: `状态 = 已完成` or `已发布`
- `按类型`: grouped by `类型`

## 05 Log

Purpose:

Store the evolution history of the knowledge base. This is the time-series memory of the agent system.

Recommended database name: `Log`

| Field name | Type | Required | Notes |
|---|---|---:|---|
| 标题 | title | yes | log title |
| 时间 | date | yes | operation time |
| 操作类型 | select | yes | ingest / query / update / lint / output / review / system |
| 涉及资料 | relation | no | links to `Raw Sources` |
| 涉及知识页 | relation | no | links to `Wiki Pages` |
| 涉及问题 | relation | no | links to `Questions` |
| 涉及输出 | relation | no | links to `Outputs` |
| 主要变化 | rich_text | yes | what changed in this operation |
| 后续动作 | rich_text | no | what should happen next |
| 操作者 | select | no | 我 / LLM / 我+LLM |

Suggested views:

- `最近日志`: sorted by `时间` descending
- `Ingest`: `操作类型 = ingest`
- `Query`: `操作类型 = query`
- `Lint`: `操作类型 = lint`
- `System`: `操作类型 = system`

## Field Naming Notes

- Keep the field names in Chinese so they match the live FlowUS workspace and remain readable to the user.
- Before an agent writes by field name, it must confirm the field exists.
- If FlowUS MCP returns field IDs instead of names, maintain the name-to-ID mapping in `docs/setup/mcp-integration.md`.
