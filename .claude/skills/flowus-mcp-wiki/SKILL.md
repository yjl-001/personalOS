---
name: flowus-mcp-wiki
description: Maintain a FlowUS-based LLM Wiki personal knowledge base through FlowUS MCP. Use when Codex needs to ingest FlowUS Raw Sources, update Wiki Pages, answer or file Questions, create Outputs, write Log entries, validate FlowUS database schemas, run FlowUS MCP smoke tests, or operate the five-table FlowUS personal knowledge system.
---

# FlowUS MCP Wiki

Use this skill to maintain the user's FlowUS LLM Wiki through FlowUS MCP.

Canonical FlowUS structure:

```text
Raw Sources -> Wiki Pages -> Questions -> Outputs -> Log
```

Local project references:

- Mapping and IDs: `flowus-llm-wiki/mcp-integration.md`
- Full schema and field meanings: `flowus-llm-wiki/schema.md`
- Test history: `flowus-llm-wiki/test-report.md`
- Skill references: `references/`
- Smoke script: `scripts/flowus_mcp_smoke.rb`

## First Steps

1. Confirm FlowUS MCP is callable. If no FlowUS tool is injected, use the smoke script or direct MCP JSON-RPC over the configured endpoint.
2. Read `references/flowus-mcp-patterns.md` before writing FlowUS data.
3. For schema-sensitive work, read `references/schema-contract.md`.
4. For troubleshooting or validation, run `scripts/flowus_mcp_smoke.rb`.

## Stable Write Pattern

Always create FlowUS database records in three steps:

```text
1. API-createPage: create only the title in parent.database_id
2. API-updatePage: write select, multi_select, rich_text, number, date, url, relation
3. API-putMarkdown: write page body
```

Do not pass many properties into `API-createPage`; real testing showed this can trigger FlowUS API 500 errors.

## Query Strategy

- Use `API-queryDatabase` for user-created or already visible database rows.
- Use saved page IDs for pages created during the current agent run.
- Use `API-search` to find MCP-created pages by title.
- Use `API-getPage` for authoritative property verification.
- Use `API-getMarkdown` to verify page body round trips.

## Relationship Rules

Use relation fields, not markdown-only links, for core knowledge graph edges:

- `Raw Sources.关联 Wiki Pages`
- `Raw Sources.关联 Questions`
- `Wiki Pages.相关资料`
- `Wiki Pages.相关问题`
- `Wiki Pages.相关页面`
- `Questions.相关资料`
- `Questions.相关知识页`
- `Questions.输出成果`
- `Outputs.来源问题`
- `Outputs.来源知识页`
- `Outputs.来源资料`
- `Log.涉及资料`
- `Log.涉及知识页`
- `Log.涉及问题`
- `Log.涉及输出`

For `Wiki Pages.相关页面`, explicitly write both sides:

```text
A.相关页面 includes B
B.相关页面 includes A
```

Do not rely on FlowUS MCP to auto-backfill same-table self-relations.

## Ingest Workflow

When ingesting a Raw Source:

1. Locate the Raw Source, usually by `API-queryDatabase` on `处理状态 = 未处理`, or by `API-search` if title is known.
2. Read the Raw Source fields and Markdown body.
3. Search relevant `Wiki Pages` and `Questions`.
4. Produce a compact source summary:
   - 一句话结论
   - 核心观点
   - 关键证据
   - 对已有知识库的影响
   - 新增或更新的 Wiki Pages
   - 争议 / 不确定性
   - 后续问题
5. Create or update impacted Wiki Pages.
6. Create or update Questions if useful.
7. Update the Raw Source:
   - `处理状态 = 已入库`
   - `摘要`
   - `关键摘录`
   - `关联 Wiki Pages`
   - `关联 Questions`
   - `处理记录`
   - `最后处理时间`
8. Write a `Log` record with all involved relations.
9. Return a concise report with created pages, updated pages, uncertainties, and next steps.

## Query Workflow

When answering against the knowledge base:

1. Search `Questions`, `Wiki Pages`, and `Raw Sources`.
2. Read the relevant pages and sources.
3. Answer with conclusion, evidence, uncertainty, and next actions.
4. If the answer has long-term value, write it back:
   - Update or create a `Question`
   - Update or create a `Wiki Page`
   - Create an `Output` if it is a deliverable
   - Write a `Log`

## Validation

Run the smoke script from the project root:

```bash
ruby skills/flowus-mcp-wiki/scripts/flowus_mcp_smoke.rb db-audit
ruby skills/flowus-mcp-wiki/scripts/flowus_mcp_smoke.rb e2e-test
```

Use `FLOWUS_MCP_INTEGRATION=/path/to/mcp-integration.md` to test a different mapping file.

The E2E test creates records titled `MCP E2E Test ...`. Deleting those FlowUS cloud records requires user confirmation or user-side cleanup.

