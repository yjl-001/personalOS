# Tested FlowUS MCP Behavior

Last verified: 2026-05-04.

## Passed

- MCP server handshake
- Token and permission check through `API-getMe`
- Tool listing
- Schema read for five core databases through `API-getDatabase`
- Database record creation through `API-createPage`
- Property updates through `API-updatePage`
- Markdown body write/read through `API-putMarkdown` and `API-getMarkdown`
- Cross-table relation writes and reverse relation readback
- `Wiki Pages.相关页面` self-relation when both sides are explicitly written
- Log creation with relations to Raw Sources, Wiki Pages, Questions, and Outputs
- `API-search` can find MCP-created pages

## Required Write Strategy

Create page with title only, then update properties, then put Markdown.

This is not just stylistic; full-property `API-createPage` returned internal server errors in testing.

## Query Caveat

`API-queryDatabase` did not always return MCP-created pages immediately in earlier tests. Later retests passed, but agents should still prefer saved page IDs and `API-search` for pages created in the current run.

## Self-Relation Caveat

Same-table `Wiki Pages.相关页面` did not reliably auto-backfill. Write both sides explicitly.

## Current Smoke Command

From project root:

```bash
ruby skills/flowus-mcp-wiki/scripts/flowus_mcp_smoke.rb db-audit
ruby skills/flowus-mcp-wiki/scripts/flowus_mcp_smoke.rb e2e-test
```

The script reads FlowUS MCP URL from `~/.codex/config.toml` and database IDs from `flowus-llm-wiki/mcp-integration.md` unless `FLOWUS_MCP_INTEGRATION` is set.

