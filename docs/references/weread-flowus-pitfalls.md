# WeRead To FlowUS Pitfalls

## Confirmed Pitfalls

### 1. WeRead MCP may not be injected into the current Codex turn

Even if `~/.codex/config.toml` contains a valid `weread` server entry, the active tool list for the current turn may not include the WeRead tools yet.

Preferred fallback:

- use `npx -y mcp-server-weread`
- speak MCP over stdio
- call `search_books` and `get_book_notes_and_highlights` directly

### 1b. WeRead notebook fetch may return 401

Observed failure:

- `get_book_notes_and_highlights` fails against `https://weread.qq.com/api/user/notebook`
- server retries and still returns `401`

Meaning:

- the pipeline is intact
- the current WeRead auth material is stale

Preferred recovery:

1. refresh CookieCloud
2. if CookieCloud is unreliable, refresh `WEREAD_COOKIE`
3. rerun the pipeline in dry-run mode first

### 2. Reading progress matters

Some books that the user asks to “沉淀” are not actually finished.

Required behavior:

- inspect `finish_reading`
- inspect `reading_status.progress`
- if progress < 100 or finish flag is false, mark the result as `阶段性入库`
- reflect that in Raw Source summary, Wiki pending checks, and follow-up actions

### 3. FlowUS `API-createPage` wrapper can misbehave for database rows

Observed failure modes:

- creates a normal page in workspace root instead of a database row
- returns `500 internal_error`

Preferred create strategy:

- do not rely on `API-createPage` for database rows in this workflow
- use `API-batch` with `POST /v2/pages`
- pass `parent.database_id`
- create title only first

### 4. FlowUS updates are safer than FlowUS creates

Observed behavior:

- `API-updatePage` and `API-putMarkdown` are reliable once a true database row exists
- wrapper trouble is concentrated in record creation

Preferred write pattern:

1. batch-create title-only records
2. update properties
3. put markdown
4. verify through `API-queryDatabase`

### 5. `API-getPage` alone is not enough verification

`API-getPage` is useful, but for this workflow the authoritative check is:

- `API-queryDatabase` by title in the target database
- confirm the parent is the expected `database_id`
- optionally `API-getMarkdown` to confirm body round-trip

### 6. Mistaken root pages need explicit cleanup

If a create bug produces workspace-root pages:

- keep their page ids
- create the correct database rows first
- only then trash the mistaken pages
- never delete the correct records by title alone

## Recommended Recovery Procedure

If a write partially fails:

1. stop creating more records
2. verify which ids are true database rows
3. complete updates only on the verified rows
4. clean mistaken root pages after success
5. record the cleanup in the final report
