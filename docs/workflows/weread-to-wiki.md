# Workflow: WeRead To Wiki

Turn a finished or worth-capturing WeRead book into structured FlowUS records across `Raw Sources`, `Wiki Pages`, `Questions`, and `Log`.

## Use Cases

- The user just finished a book and wants reusable knowledge, not just raw highlights.
- The user wants to backfill an older WeRead book into the knowledge base.
- The user wants one book to update an existing topic page or cross-book question.

## Preconditions

1. WeRead MCP is available and supports at least:
   - `get_bookshelf`
   - `search_books`
   - `get_book_notes_and_highlights`
   - `get_book_best_reviews`
2. FlowUS MCP is available and the five core databases already exist.
3. The required fields from `docs/specs/schema.md` already exist.

Preferred entrypoints:

- Prefer [weread_flowus_pipeline.js](/Users/yjl/Desktop/PersonalOS/scripts/weread_flowus_pipeline.js)
- Review [weread-flowus-pitfalls.md](/Users/yjl/Desktop/PersonalOS/docs/references/weread-flowus-pitfalls.md) when debugging known failure modes

## User Prompts

Process by title:

```text
Use WeRead MCP to process "Book Title" and write it into my FlowUS Wiki.
```

Process the most recently finished book:

```text
Use WeRead MCP to find the most recently finished book and write it into my FlowUS Wiki.
If finish status is ambiguous, show me candidate books first.
```

## Agent Steps

1. Use `search_books` or `get_bookshelf` to locate the target book.
2. Read the core book metadata:
   - title
   - author or translator
   - category
   - reading progress or finish status
3. Use `get_book_notes_and_highlights` to fetch highlights and notes.
4. Optionally use `get_book_best_reviews` for external perspective:
   - only when you need disagreement, counterpoints, or calibration
   - do not let reviews dominate the book synthesis
5. Search `Raw Sources` to see whether this book already exists.
6. Generate a reading synthesis that includes at least:
   - one-sentence conclusion
   - key ideas
   - key evidence
   - impact on the existing knowledge base
   - candidate Wiki Pages
   - disagreement or uncertainty
7. Search related `Wiki Pages` and `Questions`.
8. Decide the write strategy:
   - create a book-level Wiki Page
   - update existing topic pages
   - create `Questions` only when they are meaningful
9. Execute the FlowUS writes:
   - create or update `Raw Sources`
   - create or update `Wiki Pages`
   - create or update `Questions`
   - write a `Log`
10. Return a short report.

## Execution Priority

Recommended stable order:

1. WeRead retrieval
2. local synthesis and stage decision
3. FlowUS title-only record creation
4. FlowUS property updates
5. FlowUS Markdown writes
6. FlowUS read-back verification
7. mistaken-page cleanup if needed

Do not treat `API-createPage` as the default database-row creation path for this workflow.

## Raw Source Write Contract

Keep one main `Raw Sources` record per book as the container for the original reading material.

Suggested field mapping:

- `标题`: book title
- `类型`: `书`
- `来源链接`: a stable WeRead link for the book
- `作者`: author, with translator if useful
- `收集日期`: the ingest date
- `处理状态`: `已入库`
- `主题标签`: the core topics of the book, such as `心理学`, `决策`, `知识管理`
- `可信度`: usually `中`
- `重要性`: 1-5 based on value to the personal knowledge base
- `摘要`: the whole-book synthesis
- `关键摘录`: the best excerpts, notes, or chapter highlights worth preserving
- `关联 Wiki Pages`: the pages created or updated in this run
- `关联 Questions`: the high-value questions triggered by the book
- `处理记录`: which MCP tools were used, whether reviews were consulted, and what was written back
- `最后处理时间`: the processing date

If the book is not finished:

- the first line of `摘要` must clearly say this is `阶段性入库`
- `待验证点` must include the current reading progress
- the follow-up action must include a post-finish review

Suggested page-body structure:

```text
# Book Title

## Basic Information

## One-Sentence Conclusion

## My Core Excerpts

## Highlights and Notes by Section

## Impact on the Knowledge Base

## Pending Verification
```

## Wiki Page Decision Rules

By default, create or update at least one book page.

A book page should carry:

- the core argument of the book
- what you actually agree or disagree with
- how it changed your prior understanding
- links to other books or topic pages

Only split out a separate topic page when:

- the topic will recur across multiple books
- it has durable value for long-term projects, writing, or decisions
- one single book is not enough to hold the concept

Common split pattern:

- book page: `《思考，快与慢》`
- topic page: `系统 1 / 系统 2`
- method page: `How to turn reading notes into reusable frameworks`

## Question Decision Rules

Create or update a `Question` when at least one of these is true:

- the book materially changes the answer to a long-term question
- the book reveals an important unresolved contradiction
- the question is worth comparing across multiple books later

Do not create one database record for every small stray thought.

## Log Write Contract

Every successful WeRead ingestion should create one `Log` record:

- `标题`: `微信读书沉淀：《书名》`
- `操作类型`: `ingest`
- `主要变化`: which sources, pages, and questions were created or updated
- `后续动作`: for example, continue with another book on the same topic or revisit pending checks
- `操作者`: `我+LLM`

## Quality Bar

- Do not dump every highlight directly into a Wiki Page.
- Raw Sources preserve the source layer; Wiki Pages preserve synthesis.
- Attach important conclusions to sources whenever possible.
- When new material conflicts with older conclusions, record it under disagreement, uncertainty, or update history.
- If more than 5 Wiki Pages will be affected, show a preview list first.

## Confirmed Pitfalls

- WeRead MCP may be configured but still absent from the current session tool list.
- A user saying “finished” does not guarantee MCP returns `finish_reading = true`.
- The FlowUS `API-createPage` wrapper may create a workspace-root page instead of a database row.
- `API-batch -> POST /v2/pages` has been more reliable than the wrapper for record creation.
- `API-getPage` alone is not enough verification; use `API-queryDatabase` by title to confirm the row exists in the correct database.
- If a mistaken root page is created, clean it only after the correct database record is safely written.

## Return Format

```text
WeRead ingestion completed:
- Book: "..."
- New Raw Sources:
- New Wiki Pages:
- Updated Wiki Pages:
- New Questions:
- Log written:

Things to notice:
-

Suggested next step:
-
```
