# Post-MCP Fixes

These were the recommended follow-up fixes after the 2026-05-04 end-to-end FlowUS MCP test. They were not all blockers, but fixing them made agent maintenance more stable and removed special-case branching.

## P0: Recommended Immediately

### 1. Add the self-relation field `相关页面` to `Wiki Pages`

Current state:

The field was missing.

How to fix:

- open the `Wiki Pages` database
- add a new field named `相关页面`
- choose relation type
- point it to `Wiki Pages` itself
- use a two-way connection

Why:

Wiki pages need lateral links such as `LLM Wiki` -> `RAG`, `FlowUS MCP`, and `个人知识库 OS`. Without this field, agents can only link sources and questions, which leaves the knowledge graph flatter than intended.

### 2. Rename `Log.涉及知识库` to `Log.涉及知识页`

Current state:

The field existed, but the name did not match the schema.

How to fix:

- open the `Log` database
- find the field `涉及知识库`
- rename it to `涉及知识页`

Why:

The field actually points to `Wiki Pages`, so `涉及知识页` is more accurate and matches the schema plus agent expectations.

## P1: Recommended This Week

### 3. Rename `Raw Sources.关键摘要` to `Raw Sources.关键摘录`

Current state:

The field existed, but the name drifted away from the schema.

How to fix:

- open `Raw Sources`
- find the field `关键摘要`
- rename it to `关键摘录`

Why:

The field is meant for source excerpts, timestamps, and quotations, not for summaries. The actual summary already belongs in the `摘要` field.

### 4. Convert `Wiki Pages.主题标签` into a multi-select field

Current state:

`主题标签` was a `rich_text` field.

Desired state:

- field name: `主题标签`
- field type: multi-select

Why:

Tags should support filtering, grouping, and view-level operations. Plain text is a poor fit and is harder for agents to write consistently.

Important note:

FlowUS usually cannot convert a text field into multi-select without loss. The safer migration is:

1. create `主题标签 2`
2. set it to multi-select
3. migrate values manually or with an agent
4. delete the old `主题标签`
5. rename `主题标签 2` back to `主题标签`

If you still have very little real data, recreating the field directly is fine.

### 5. Remove the wrong option `2026-04-29` from `Raw Sources.处理状态`

Current state:

The single-select options for `处理状态` accidentally included a date.

How to fix:

- open `Raw Sources`
- edit the `处理状态` options
- delete `2026-04-29`

Why:

This was likely created accidentally during CSV import or paste. Leaving it in place makes status selection confusing for both humans and agents.

## P2: Can Be Done Later

### 6. Clean up MCP test records

The test records all contain:

```text
MCP E2E
```

Suggested cleanup targets:

- `MCP E2E Minimal Raw Source`
- `MCP E2E Query Visible Raw Source`
- `MCP E2E Test 20260504132654 ...`
- `MCP E2E Test 20260504133005 ...`

They are distributed across:

- `Raw Sources`
- `Wiki Pages`
- `Questions`
- `Outputs`
- `Log`

Because this is cloud data deletion, manual cleanup inside FlowUS is the safest default.

### 7. Keep the MCP test script and report

These local files are worth preserving:

- `scripts/flowus_mcp_smoke.rb`
- `docs/setup/test-report.md`
- `docs/setup/mcp-integration.md`

Why:

They are useful whenever FlowUS MCP or the schema changes and you want a fresh smoke test.

## What Did Not Need Changes

### 1. The five database IDs

The UUIDs before `#` were confirmed to be the correct table or database IDs.

### 2. Core two-way relations

The important reverse relations already worked:

- Raw Source -> Wiki Page
- Raw Source -> Question
- Wiki Page -> Raw Source
- Question -> Wiki Page
- Output -> Question
- Log -> Raw Source

### 3. MCP permissions

The integration already had the necessary access:

- pages read/write
- blocks read/write
- databases read/write
- search read

## Agent Workflow Adjustment

Going forward, agents should use this write pattern:

```text
1. API-createPage: title only
2. API-updatePage: fields and relations
3. API-putMarkdown: page body
4. API-getPage / API-search: read-back verification
```

Do not make agents push a large property payload into `API-createPage`.

Query strategy:

```text
For user-created records: API-queryDatabase
For freshly agent-created records: API-search or saved page IDs
```

## Recommended Fix Order

1. add `Wiki Pages.相关页面`
2. rename `Log.涉及知识库` to `Log.涉及知识页`
3. rename `Raw Sources.关键摘要` to `Raw Sources.关键摘录`
4. convert `Wiki Pages.主题标签` to multi-select
5. remove `2026-04-29` from `Raw Sources.处理状态`
6. delete the `MCP E2E` test records
