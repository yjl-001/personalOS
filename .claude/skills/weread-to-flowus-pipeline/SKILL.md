---
name: weread-to-flowus-pipeline
description: Execute the full WeRead-to-FlowUS ingestion chain safely. Use when Codex needs to fetch a book from WeRead, inspect reading progress, pull highlights and notes, create verified FlowUS database records, and avoid known MCP wrapper failures. Trigger this skill for requests like “把微信读书这本书沉淀到 FlowUS”, “处理我刚读完的微信读书”, “从微信读书写入 Raw Sources 和 Wiki Pages”, or any task that specifically needs the operational bridge from WeRead MCP to FlowUS MCP.
---

# WeRead To FlowUS Pipeline

Run the operational bridge from WeRead MCP to FlowUS MCP with the safest known execution path.

If the current workspace contains this repo, read these first:

- `AGENTS.md`
- `docs/workflows/weread-to-wiki.md`
- `docs/references/weread-flowus-pitfalls.md`

## Preferred Execution Path

When the workspace contains the pipeline script, prefer it over ad hoc MCP plumbing:

```bash
node scripts/weread_flowus_pipeline.js ingest --title "书名"
node scripts/weread_flowus_pipeline.js ingest --title "书名" --apply
```

Use dry-run first unless the user clearly asked you to write into FlowUS now.

## Workflow

### 1. Confirm intent

Determine whether the user wants:

- preview only
- full ingest
- cleanup of mistaken pages

If they want writes, proceed without asking again.

### 2. Fetch and inspect source state

Always inspect:

- matched book title
- current reading progress
- highlight count
- note count

If the book is not finished, treat it as `阶段性入库` and carry that wording through the whole write.

### 3. Prefer the repo script

If `scripts/weread_flowus_pipeline.js` exists, use it as the primary execution path.

Why:

- it already encodes the known MCP workarounds
- it uses `API-batch` for record creation
- it verifies database writes through `API-queryDatabase`

### 4. Avoid known bad create path

Do not rely on FlowUS `API-createPage` wrapper for database rows in this workflow.

Prefer:

1. `API-batch`
2. `POST /v2/pages`
3. title-only database records
4. `API-updatePage`
5. `API-putMarkdown`

### 5. Verify success

Do not stop after a “create succeeded” response.

Success requires:

- correct database parent
- queryable row in the expected database
- markdown body present
- no accidental workspace-root duplicate

### 6. Recover cleanly

If wrapper-created root pages appear:

- keep the mistaken ids
- finish the correct database-row path
- only then trash the mistaken pages

## Reporting

Return:

- whether this was staged or finished ingest
- created record ids or URLs
- any cleanup performed
- remaining uncertainty

## References

Read [references/pipeline-reference.md](references/pipeline-reference.md) for:

- validation standards
- fallback rules
- known wrapper failures
