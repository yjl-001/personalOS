# FlowUS MCP Patterns

## Tools

Observed FlowUS MCP tools:

- `API-search`
- `API-semanticSearch`
- `API-getMe`
- `API-createPage`
- `API-getPage`
- `API-updatePage`
- `API-getPageProperty`
- `API-getBlock`
- `API-updateBlock`
- `API-getBlockChildren`
- `API-appendBlockChildren`
- `API-createDatabase`
- `API-getDatabase`
- `API-updateDatabase`
- `API-queryDatabase`
- `API-getMarkdown`
- `API-putMarkdown`
- `API-batch`

Use these names if FlowUS tools are exposed directly. If they are not injected into Codex, use the repo script `scripts/flowus_mcp_smoke.rb` as the JSON-RPC client.

## Stable Record Creation

Use the tested three-step write pattern:

```text
API-createPage:
  parent: { database_id: "..." }
  properties: { title-field: title }

API-updatePage:
  properties: all non-title fields and relations

API-putMarkdown:
  markdown body
```

Avoid sending all properties during `API-createPage`; it returned HTTP 500 during testing.

## Property Value Shapes

Title:

```json
{"type":"title","title":[{"type":"text","text":{"content":"Title","link":null},"plain_text":"Title","href":null}]}
```

Rich text:

```json
{"type":"rich_text","rich_text":[{"type":"text","text":{"content":"Text","link":null},"plain_text":"Text","href":null}]}
```

Select:

```json
{"type":"select","select":{"name":"已入库"}}
```

Multi-select:

```json
{"type":"multi_select","multi_select":[{"name":"AI"},{"name":"知识管理"}]}
```

Date:

```json
{"type":"date","date":{"start":"2026-05-04","end":null,"time_zone":null}}
```

Relation:

```json
{"type":"relation","relation":[{"id":"page-id"}]}
```

Checkbox:

```json
{"type":"checkbox","checkbox":true}
```

Number:

```json
{"type":"number","number":5}
```

URL:

```json
{"type":"url","url":"https://example.com"}
```

## Search and Query

Use `API-queryDatabase` for normal database filtering, especially user-created rows.

Use `API-search` for records created by the MCP integration or when title search through `queryDatabase` behaves oddly.

Use `API-getPage` whenever a page ID is known.

During a single workflow, save page IDs immediately after creation and reuse them instead of re-searching.

## Same-Table Relation Caveat

`Wiki Pages.相关页面` is a self-relation. FlowUS MCP did not reliably auto-backfill the reverse side.

Always write both sides:

```text
Update A.相关页面 = [B]
Update B.相关页面 = [A]
```

Cross-table dual relations worked as expected during testing.
