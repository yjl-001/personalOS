# FlowUS MCP Test Report

测试日期：2026-05-04

## Summary

FlowUS MCP 端到端流程已跑通。

通过项目：

- MCP server 握手
- token / 权限验证
- 工具列表读取
- 5 个多维表 schema 读取
- 创建数据库记录
- 更新记录属性
- 写入 Markdown 正文
- 建立双向关联
- 创建 Log
- 回读验证
- 搜索 MCP 创建的页面

需要注意：

- `API-queryDatabase` 对 MCP 刚创建的记录没有稳定返回。
- `API-search` 和 `API-getPage` 可以稳定找到/读取 MCP 创建的页面。
- `API-createPage` 一次性传入大量属性时曾返回 500，改成“先创建标题，再 update 属性”后稳定。

## Bot Identity

MCP integration 名称：`personalOS`

权限包含：

- `pages.read`
- `pages.write`
- `blocks.read`
- `blocks.write`
- `databases.read`
- `databases.write`
- `search.read`
- `users.read`

## Database Schema Audit

### Raw Sources

状态：可读写。

差异：

- 缺少 `关键摘录`
- 多出 `关键摘要`
- `处理状态` 多出选项 `2026-04-29`

关系：

- `关联 Wiki Pages` -> `Wiki Pages`，双向。
- `关联 Questions` -> `Questions`，双向。

### Wiki Pages

状态：可读写。

差异：

- 缺少自关联字段 `相关页面`
- `主题标签` 是 `rich_text`，schema 期望 `multi_select`

关系：

- `相关资料` -> `Raw Sources`，双向。
- `相关问题` -> `Questions`，双向。

### Questions

状态：可读写。

差异：无阻断问题。

关系：

- `相关资料` -> `Raw Sources`，双向。
- `相关知识页` -> `Wiki Pages`，双向。
- `输出成果` -> `Outputs`，双向。

### Outputs

状态：可读写。

差异：无阻断问题。

关系：

- `来源问题` -> `Questions`，双向。
- `来源知识页` -> `Wiki Pages`，双向。
- `来源资料` -> `Raw Sources`，双向。

### Log

状态：可读写。

差异：

- 字段 `涉及知识库` 对应 schema 中的 `涉及知识页`

关系：

- `涉及资料` -> `Raw Sources`，双向。
- `涉及知识库` -> `Wiki Pages`，双向。
- `涉及问题` -> `Questions`，双向。
- `涉及输出` -> `Outputs`，双向。

## End-to-End Test

最终测试 marker：

```text
MCP E2E Test 20260504133005
```

创建记录：

| 类型 | ID | 标题 |
|---|---|---|
| Raw Source | `79da1057-c76e-4c07-ae12-19a6e2cd9f1b` | MCP E2E Test 20260504133005 Raw Source |
| Wiki Page | `ec1b3a0d-0e03-4c90-9f02-f1c5b89e6659` | MCP E2E Test 20260504133005 Wiki Page |
| Question | `7352daa6-f8d2-4392-870c-69d6de1a13af` | MCP E2E Test 20260504133005 Question |
| Output | `9416b020-82e1-4144-924a-1f8a4882b914` | MCP E2E Test 20260504133005 Output |
| Log | `16c0d6d1-5959-461c-9768-ed60522344d6` | MCP E2E Test 20260504133005 Log |

验证结果：

| 检查项 | 结果 |
|---|---|
| search_raw_by_title | PASS |
| raw_status_updated | PASS |
| raw_links_wiki | PASS |
| raw_links_question | PASS |
| wiki_links_raw | PASS |
| question_links_wiki | PASS |
| output_links_question | PASS |
| log_links_raw | PASS |
| markdown_roundtrip | PASS |
| query_bot_created_raw_by_title | Known limitation |

## Recommended Agent Strategy

### 创建记录

使用稳定的三步法：

```text
1. API-createPage: 只创建标题
2. API-updatePage: 写入字段和关系
3. API-putMarkdown: 写入正文
```

### 查找记录

对于用户在 FlowUS 里手动创建的记录：

```text
API-queryDatabase
```

对于 Agent 刚创建或已知标题的记录：

```text
API-search
API-getPage
```

对于 Agent 当前流程中创建的记录：

```text
保存 page id，后续直接 API-getPage / API-updatePage
```

## Recommended Cleanup

测试记录均以 `MCP E2E` 开头。确认无用后，可在 FlowUS 中手动筛选并删除。

需要删除的测试记录包括：

- `MCP E2E Minimal Raw Source`
- `MCP E2E Query Visible Raw Source`
- `MCP E2E Test 20260504132654 ...`
- `MCP E2E Test 20260504133005 ...`

删除属于云端数据删除，建议由用户在 FlowUS 中手动操作。

## Retest After Schema Fixes

复测日期：2026-05-04

最终复测 marker：

```text
MCP E2E Test 20260504134357
```

复测结论：PASS。

新增覆盖：

- `Raw Sources.关键摘录` 字段已修正并可写入。
- `Wiki Pages.主题标签` 已是 multi_select 并可写入。
- `Log.涉及知识页` 字段已修正并可写入。
- `Wiki Pages.相关页面` 自关联可写入。
- Wiki 自关联需要 Agent 显式双边写入：A 关联 B 后，也要更新 B 关联 A。不要依赖 MCP 自动反向回填。

复测创建记录：

| 类型 | ID | 标题 |
|---|---|---|
| Raw Source | `b9dee275-925b-4d29-ac88-b8e3c1e802bb` | MCP E2E Test 20260504134357 Raw Source |
| Wiki Page | `ed894b7e-b8fd-44f4-8c49-fd9d1ab7d0ec` | MCP E2E Test 20260504134357 Wiki Page |
| Related Wiki Page | `0cd1603c-c3d6-4366-a2e0-9d9d85bd7965` | MCP E2E Test 20260504134357 Related Wiki Page |
| Question | `f43d012d-4242-4f4d-b67d-73837cd5dc6a` | MCP E2E Test 20260504134357 Question |
| Output | `f5b395ad-e505-4bf4-8d55-83c53d7b1235` | MCP E2E Test 20260504134357 Output |
| Log | `cfec884d-6b1a-4f79-a5f9-6468c45e320c` | MCP E2E Test 20260504134357 Log |

复测验证结果：

| 检查项 | 结果 |
|---|---|
| search_raw_by_title | PASS |
| query_bot_created_raw_by_title | PASS |
| raw_status_updated | PASS |
| raw_links_wiki | PASS |
| raw_links_question | PASS |
| wiki_links_raw | PASS |
| wiki_links_related_page | PASS |
| related_page_links_wiki_back | PASS |
| question_links_wiki | PASS |
| output_links_question | PASS |
| log_links_raw | PASS |
| markdown_roundtrip | PASS |
