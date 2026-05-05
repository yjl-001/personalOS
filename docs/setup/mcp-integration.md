# FlowUS MCP Integration

This file maps the local blueprint to the real FlowUS MCP environment. Different MCP servers and agents may expose different tool names, so this document defines the capability contract rather than binding itself to one exact implementation.

## Connection Information

Use the documentation for your actual FlowUS MCP server as the source of truth.

You usually need:

- a FlowUS MCP token
- the root page `个人知识库 OS`
- the page or database IDs for the five core databases
- a mapping from field names to field IDs

## How To Get Page or Table IDs

In FlowUS, pages and database tables can usually be identified from their share links. A page-level table is often treated as a page object, so some tools call its ID `tablePageId`.

### Recommended Method: Extract the UUID from the Link

1. Open the target page or target database in FlowUS.
2. Copy the link from the share or more menu.
3. Paste it into a temporary note.
4. Find the UUID, which usually looks like:

```text
df7cd54f-1c21-4fc1-9fd8-ce81be1918a5
```

5. That UUID is the page ID or page-level database ID.

Common link shapes:

```text
https://flowus.cn/share/df7cd54f-1c21-4fc1-9fd8-ce81be1918a5
https://flowus.cn/xxx/df7cd54f-1c21-4fc1-9fd8-ce81be1918a5
```

If the link includes query parameters:

```text
https://flowus.cn/share/df7cd54f-1c21-4fc1-9fd8-ce81be1918a5?code=...
```

Use only the UUID before the `?`.

### Page ID vs Database ID

- Normal page: copy the page link and extract the UUID.
- Page-level database: open the database page, copy the link, extract the UUID. This is the `tablePageId`.
- One row inside a database: open the row as a page and copy its UUID. This is the record page ID, not the database ID.

For this system, prioritize recording the five page-level database IDs:

- `Raw Sources`
- `Wiki Pages`
- `Questions`
- `Outputs`
- `Log`

### Validation Method

If you are unsure whether the UUID is a table ID:

1. Put it into the `Database ID Mapping` section below.
2. Query the target with FlowUS MCP.
3. If FlowUS returns schema or records, it is the correct database ID.
4. If FlowUS returns normal page content, you copied a page ID instead of a table ID.
5. If it returns `404` or a permission error, verify the ID and confirm MCP access.

## Database ID Mapping

Once completed, agents should use these IDs directly instead of searching for the databases repeatedly.

Important note:

When FlowUS copies a database link, you may see `pageUUID#fragmentUUID`. Most MCP or API parameters need the standalone UUID, not the full `UUID#UUID` string. The table below stores both parts separately.

| Logical name | FlowUS name | Preferred page or table ID | URL fragment or view/block ID |
|---|---|---|---|
| root | 个人知识库 OS | a548f75d-3010-45d8-8fc1-6baae0f77695 |  |
| dashboard | 00 Dashboard | 49d67329-1763-4db7-96e5-f748af920ed6 |  |
| raw_sources | Raw Sources | 39e9ec92-a952-4ec8-9db0-45adee987a58 | 308f70cb-6d0d-4810-ab02-68cb47e49ffa |
| wiki_pages | Wiki Pages | 9988c8c6-ceed-4eba-9bc8-5d9d96b303d6 | be040857-3dec-441c-99ae-1967de0ef12a |
| questions | Questions | 015944ff-f203-4370-bae8-ed2483c06cda | d2e034cb-e655-407b-a59b-fd649dd2d9ff |
| outputs | Outputs | 1a04b51b-6d35-4eef-82ed-1aac30908482 | 9f441956-22b6-4925-b988-07de704da4be |
| log | Log | 20d39f53-8c09-4dc6-975b-5fffd5418e1d | b2781d5a-5514-4206-b917-35eaed90ec05 |
| system_rules | 99 System / LLM 维护规则 | 0c9e3c6a-3780-42d6-8946-5facf82eeeda |  |

When connecting an MCP client, test the `Preferred page or table ID` first. If FlowUS says “not a table”, “table not found”, or only returns plain page content, then test the fragment or view/block ID.

## Required MCP Capabilities

The agent should have at least these capabilities:

| Capability | Purpose |
|---|---|
| search pages | search `Wiki Pages`, `Questions`, and `Raw Sources` |
| query database | filter records by status, date, or tags |
| read page blocks | read page body content |
| create page | create `Wiki Pages`, `Questions`, and `Outputs` |
| update page properties | update database fields |
| append blocks | add summaries, update history, or evidence |
| replace or patch blocks | revise current understanding in a Wiki Page |
| create relation | link sources, questions, pages, and outputs |

If the MCP server does not support block-level patching, use the conservative strategy:

- append an `更新记录`
- update the top summary fields
- avoid rewriting large bodies destructively

## Safe Write Strategy

### Small Updates Can Be Written Directly

- updating one Raw Source status
- creating one Wiki Page
- creating one Question
- creating one Log entry
- appending an update note to an existing page

### Large Updates Require a Preview First

- more than 5 pages will be affected
- a stable page’s core conclusion will be changed
- pages will be merged
- a page will be retired
- database fields or tag systems will be changed

Preview format:

```text
Planned changes:
- Raw Sources: 1 update
- Wiki Pages: 2 creates, 4 updates
- Questions: 1 create
- Log: 1 create

Risks that need confirmation:
- rewriting the core conclusion of stable page "..."
- merging "..." and "..."
```

## Field ID Mapping Template

After MCP is connected, it is useful to maintain a JSON or table like this:

```json
{
  "raw_sources": {
    "标题": "TODO",
    "类型": "TODO",
    "处理状态": "TODO",
    "摘要": "TODO",
    "关联 Wiki Pages": "TODO"
  },
  "wiki_pages": {
    "页面名称": "TODO",
    "页面类型": "TODO",
    "一句话摘要": "TODO",
    "成熟度": "TODO",
    "相关资料": "TODO"
  }
}
```

## Agent Test Checklist

After FlowUS MCP is connected, validate one complete loop:

1. query one `Raw Sources` record where `处理状态 = 未处理`
2. read the page body
3. update the summary field
4. create one `Wiki Pages` record
5. create the relation from Raw Source to Wiki Page
6. update the Raw Source status to `已入库`
7. create one `Log`
8. read back the records and confirm the relations

## Tested Behavior Notes

Observed on 2026-05-04:

- the MCP endpoint and token worked
- `API-getMe` returned permissions covering pages, blocks, databases, and search with read/write
- `API-getDatabase` could read the schema of the five core databases
- `API-createPage` could create database rows
- the more stable strategy was still title-only create first, then `API-updatePage`
- `API-updatePage` could update select, multi_select, rich_text, number, date, url, and relation fields
- two-way relations worked and reverse links could be read back
- `API-putMarkdown` and `API-getMarkdown` worked for body write and verification
- `API-search` could find pages created by MCP
- `API-queryDatabase` was less stable for freshly created MCP rows; agents should prefer `API-search` or saved page IDs inside the current run
- `Wiki Pages.相关页面` self-relations could be written, but agents should explicitly write both sides

### Practical Write Pattern

Do not push many properties into `API-createPage` at once. Prefer:

```text
1. API-createPage
   - parent.database_id
   - title property only

2. API-updatePage
   - select / rich_text / number / date / url / relation

3. API-putMarkdown
   - page body

4. API-getPage / API-search
   - verify properties and relations
```

### Self-Relation Pattern

When linking two `Wiki Pages` together:

```text
1. update A.相关页面 = [B]
2. update B.相关页面 = [A]
3. read back both A and B
```
