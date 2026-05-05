# Implementation Checklist

This checklist is meant to build a first usable FlowUS knowledge system in 60 to 90 minutes. The goal is not perfection. The goal is a working first loop.

## Phase 1: Create the Root Pages

- [☑️] Create the root page: `个人知识库 OS` or `Personal Knowledge OS`
- [☑️] Create the child page: `00 Dashboard`
- [☑️] Create the child page: `99 System`
- [☑️] Under `99 System`, create the page: `LLM 维护规则`
- [☑️] Copy `data/seed/llm-maintenance-rules-flowus-page.md` into `LLM 维护规则`
- [☑️] Copy `docs/architecture/dashboard.md` into `00 Dashboard`

## Phase 2: Create the Five Core Databases

Here, “database” means a FlowUS multi-dimensional table, not a plain document page.

Recommended setup:

Create five page-level database tables directly under `个人知识库 OS`, so each database appears as its own page in the sidebar and each row can open as a page.

If you already created normal pages with the same names, do not treat them as databases. Either insert a database into those pages, or recreate them correctly as page-level databases.

Create these databases from `docs/specs/schema.md`:

- [ ] `Raw Sources`
- [ ] `Wiki Pages`
- [ ] `Questions`
- [ ] `Outputs`
- [ ] `Log`

For the first pass, only create the fields defined in the schema. Add extra fields later only after using the system in practice.

## Phase 3: Create Relation Fields

Read `docs/architecture/relationship-guide.md` first.

If FlowUS can auto-create reverse relations, create each pair only once. Do not manually create duplicate fields that represent the same edge.

- [ ] `Raw Sources` relates to `Wiki Pages`
- [ ] `Raw Sources` relates to `Questions`
- [ ] `Wiki Pages` relates to `Raw Sources`
- [ ] `Wiki Pages` relates to `Questions`
- [ ] `Wiki Pages` self-relates to `Wiki Pages`
- [ ] `Questions` relates to `Raw Sources`
- [ ] `Questions` relates to `Wiki Pages`
- [ ] `Questions` relates to `Outputs`
- [ ] `Outputs` relates to `Questions`
- [ ] `Outputs` relates to `Wiki Pages`
- [ ] `Outputs` relates to `Raw Sources`
- [ ] `Log` relates to `Raw Sources`
- [ ] `Log` relates to `Wiki Pages`
- [ ] `Log` relates to `Questions`
- [ ] `Log` relates to `Outputs`

## Phase 4: Create Views

### Raw Sources

- [ ] `未处理`
- [ ] `高价值`
- [ ] `待复查`
- [ ] `按类型`
- [ ] `按主题`

### Wiki Pages

- [ ] `全部知识页`
- [ ] `概念地图`
- [ ] `主题页`
- [ ] `自我知识`
- [ ] `待重写`
- [ ] `待验证`
- [ ] `近期更新`
- [ ] `稳定知识`

### Questions

- [ ] `正在探索`
- [ ] `高优先级`
- [ ] `待沉淀`
- [ ] `已回答`

### Outputs

- [ ] `草稿`
- [ ] `已完成`
- [ ] `按类型`

### Log

- [ ] `最近日志`
- [ ] `Ingest`
- [ ] `Query`
- [ ] `Lint`
- [ ] `System`

## Phase 5: Import Seed Data

You can import from `data/imports/*.csv` or create records manually:

- [ ] import `raw-sources.csv`
- [ ] import `wiki-pages.csv`
- [ ] import `questions.csv`
- [ ] import `outputs.csv`
- [ ] import `log.csv`

CSV import usually does not recreate database relations automatically. After import, repair the important relations manually.

## Phase 6: MCP Mapping

If the agent can already call FlowUS MCP:

- [ ] record the root page ID in `docs/setup/mcp-integration.md`
- [ ] record the five database IDs
- [ ] record important field IDs
- [ ] validate one full test flow:
  - [ ] query an unprocessed Raw Source
  - [ ] update its summary field
  - [ ] create a Wiki Page
  - [ ] create the relation
  - [ ] update the processing status
  - [ ] write a Log entry

## Phase 7: First Real Usage

Add three items:

- [ ] one article
- [ ] one personal question or idea
- [ ] one conversation excerpt or reading note

Then ask the agent:

```text
Process the most recent unprocessed Raw Source through FlowUS MCP and complete the ingest workflow.
```

Acceptance criteria:

- [ ] the Raw Source moves from `未处理` to `已入库`
- [ ] at least one Wiki Page is created or updated
- [ ] at least one follow-up Question appears
- [ ] Log contains one ingest entry
- [ ] Dashboard shows the latest changes

## Phase 8: Wait One Week Before Refactoring

Do not redesign the system in the first week. Only record friction:

- which fields were never used?
- which fields were missing?
- which templates felt too long?
- which views were opened most often?
- which agent step failed most often?

After one week, make a deliberate schema adjustment.
