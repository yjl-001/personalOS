# FlowUS MCP Test Report

Test date: 2026-05-04

## Summary

The end-to-end FlowUS MCP workflow passed.

Validated successfully:

- MCP server handshake
- token and permission check
- tool listing
- schema read for all five databases
- database-row creation
- property updates
- Markdown body writes
- two-way relations
- Log creation
- read-back verification
- search for MCP-created pages

Important caveats:

- `API-queryDatabase` was not always stable for records created moments earlier by MCP.
- `API-search` and `API-getPage` were reliable for MCP-created records.
- `API-createPage` returned `500` when many properties were passed at once; title-only create plus follow-up update was stable.

## Bot Identity

MCP integration name: `personalOS`

Permissions included:

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

Status:

Readable and writable.

Drift:

- missing `关键摘录`
- extra field `关键摘要`
- extra option `2026-04-29` in `处理状态`

Relations:

- `关联 Wiki Pages` -> `Wiki Pages`, reverse works
- `关联 Questions` -> `Questions`, reverse works

### Wiki Pages

Status:

Readable and writable.

Drift:

- missing self-relation `相关页面`
- `主题标签` was `rich_text`, while the schema expected `multi_select`

Relations:

- `相关资料` -> `Raw Sources`, reverse works
- `相关问题` -> `Questions`, reverse works

### Questions

Status:

Readable and writable.

Drift:

No blocking issues.

Relations:

- `相关资料` -> `Raw Sources`, reverse works
- `相关知识页` -> `Wiki Pages`, reverse works
- `输出成果` -> `Outputs`, reverse works

### Outputs

Status:

Readable and writable.

Drift:

No blocking issues.

Relations:

- `来源问题` -> `Questions`, reverse works
- `来源知识页` -> `Wiki Pages`, reverse works
- `来源资料` -> `Raw Sources`, reverse works

### Log

Status:

Readable and writable.

Drift:

- `涉及知识库` should match schema field `涉及知识页`

Relations:

- `涉及资料` -> `Raw Sources`, reverse works
- `涉及知识库` -> `Wiki Pages`, reverse works
- `涉及问题` -> `Questions`, reverse works
- `涉及输出` -> `Outputs`, reverse works

## End-to-End Test

Final test marker:

```text
MCP E2E Test 20260504133005
```

Created records:

| Type | ID | Title |
|---|---|---|
| Raw Source | `79da1057-c76e-4c07-ae12-19a6e2cd9f1b` | MCP E2E Test 20260504133005 Raw Source |
| Wiki Page | `ec1b3a0d-0e03-4c90-9f02-f1c5b89e6659` | MCP E2E Test 20260504133005 Wiki Page |
| Question | `7352daa6-f8d2-4392-870c-69d6de1a13af` | MCP E2E Test 20260504133005 Question |
| Output | `9416b020-82e1-4144-924a-1f8a4882b914` | MCP E2E Test 20260504133005 Output |
| Log | `16c0d6d1-5959-461c-9768-ed60522344d6` | MCP E2E Test 20260504133005 Log |

Verification result:

| Check | Result |
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

### Record Creation

Use the stable three-step write pattern:

```text
1. API-createPage: create title only
2. API-updatePage: write fields and relations
3. API-putMarkdown: write page body
```

### Record Lookup

For records created manually by the user:

```text
API-queryDatabase
```

For records just created by the agent, or for known titles:

```text
API-search
API-getPage
```

For records created during the current run:

```text
save the page ID and continue using API-getPage / API-updatePage
```

## Recommended Cleanup

All test records start with `MCP E2E`. Once they are no longer useful, filter them in FlowUS and remove them manually.

Suggested cleanup set:

- `MCP E2E Minimal Raw Source`
- `MCP E2E Query Visible Raw Source`
- `MCP E2E Test 20260504132654 ...`
- `MCP E2E Test 20260504133005 ...`

Because this is cloud data deletion, manual deletion in FlowUS is the safest default.

## Retest After Schema Fixes

Retest date: 2026-05-04

Final retest marker:

```text
MCP E2E Test 20260504134357
```

Retest conclusion: PASS.

Additional coverage:

- `Raw Sources.关键摘录` was fixed and writable
- `Wiki Pages.主题标签` was multi-select and writable
- `Log.涉及知识页` was fixed and writable
- `Wiki Pages.相关页面` self-relation was writable
- Wiki self-relations still required explicit two-sided writes by the agent

Retest created records:

| Type | ID | Title |
|---|---|---|
| Raw Source | `b9dee275-925b-4d29-ac88-b8e3c1e802bb` | MCP E2E Test 20260504134357 Raw Source |
| Wiki Page | `ed894b7e-b8fd-44f4-8c49-fd9d1ab7d0ec` | MCP E2E Test 20260504134357 Wiki Page |
| Related Wiki Page | `0cd1603c-c3d6-4366-a2e0-9d9d85bd7965` | MCP E2E Test 20260504134357 Related Wiki Page |
| Question | `f43d012d-4242-4f4d-b67d-73837cd5dc6a` | MCP E2E Test 20260504134357 Question |
| Output | `f5b395ad-e505-4bf4-8d55-83c53d7b1235` | MCP E2E Test 20260504134357 Output |
| Log | `cfec884d-6b1a-4f79-a5f9-6468c45e320c` | MCP E2E Test 20260504134357 Log |

Retest verification:

| Check | Result |
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
