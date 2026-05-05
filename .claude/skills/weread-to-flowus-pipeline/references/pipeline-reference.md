# WeRead To FlowUS Pipeline Reference

## Scope

Use this skill for the execution layer of the WeRead -> FlowUS chain.

This skill is not the high-level conceptual guide. It is the safe operator for:

- fetching WeRead book data
- deciding staged vs finished ingest
- creating verified FlowUS database rows
- avoiding known wrapper failures
- cleaning up mistaken root pages

## Preferred Local Entry Point

If the current workspace contains this repo, prefer:

`node scripts/weread_flowus_pipeline.js ingest --title "书名" --apply`

Use dry-run first when:

- the book may not be finished
- the user did not explicitly ask to write
- the notes look sparse and need human review

## Validation Standard

Treat the ingest as successful only if all are true:

- WeRead search matched the intended book
- highlights and notes were fetched
- FlowUS rows were created under the correct database ids
- FlowUS markdown write succeeded
- `API-queryDatabase` can find the rows by title

## Known Failure Modes

- WeRead MCP absent from active tool list
- WeRead notebook endpoint returns `401`
- FlowUS `API-createPage` wrapper creates workspace-root pages
- FlowUS `API-createPage` wrapper returns `500`
- user says “读完” but progress is still below 100

## Recovery Rules

- prefer `API-batch` for database-row creation
- prefer `API-updatePage` and `API-putMarkdown` after creation
- if a mistaken root page is created, keep its id and clean it only after the correct row exists
