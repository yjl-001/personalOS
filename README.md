# PersonalOS

An agent-operable starter kit for maintaining a personal knowledge base in FlowUS.

This repository is intentionally organized like an operations repo rather than a notes repo:

- `FlowUS` is the live knowledge base.
- `AGENTS.md` defines how agents should maintain it.
- `docs/` stores the canonical system design and workflows.
- `data/` stores templates, seed content, and import fixtures.
- `scripts/` stores reusable execution entrypoints.
- `skills/` stores project-local Codex skills.
- `diagnostics/` stores one-off validation and cleanup utilities.

Core principle:

> Raw Sources preserve evidence. Wiki Pages preserve synthesis. Questions drive growth. Log preserves history. Agents keep the system alive through MCP.

## Structure

```text
.
├── AGENTS.md
├── CLAUDE.md
├── README.md
├── docs
│   ├── README.md
│   ├── architecture
│   ├── references
│   ├── setup
│   ├── specs
│   └── workflows
├── data
│   ├── README.md
│   ├── imports
│   ├── seed
│   └── templates
├── scripts
│   ├── README.md
│   ├── flowus_mcp_smoke.rb
│   └── weread_flowus_pipeline.js
├── diagnostics
│   ├── README.md
│   ├── cleanup_flowus_records.rb
│   ├── lint_flowus_wiki.rb
│   └── real_ingest_flowus.rb
└── skills
    ├── README.md
    ├── flowus-mcp-wiki
    └── weread-to-flowus-pipeline
```

## Canonical FlowUS System

Create one root page in FlowUS:

```text
Personal Knowledge OS
├── 00 Dashboard
├── 01 Raw Sources
├── 02 Wiki Pages
├── 03 Questions
├── 04 Outputs
├── 05 Log
└── 99 System / LLM Maintenance Rules
```

Keep the first version small. Do not split into many databases too early.

## Quick Start

1. Create the root page `Personal Knowledge OS` in FlowUS.
2. Build the five databases from [schema.md](/Users/yjl/Desktop/PersonalOS/docs/specs/schema.md).
3. Optionally import seed rows from [data/imports](/Users/yjl/Desktop/PersonalOS/data/imports).
4. Copy [dashboard.md](/Users/yjl/Desktop/PersonalOS/docs/architecture/dashboard.md) into `00 Dashboard`.
5. Copy [llm-maintenance-rules-flowus-page.md](/Users/yjl/Desktop/PersonalOS/data/seed/llm-maintenance-rules-flowus-page.md) into `99 System / LLM Maintenance Rules`.
6. Complete the first-pass setup check with [implementation-checklist.md](/Users/yjl/Desktop/PersonalOS/docs/setup/implementation-checklist.md).
7. Keep [AGENTS.md](/Users/yjl/Desktop/PersonalOS/AGENTS.md) in the workspace root so Codex and similar agents can follow the repo contract.
8. Fill in live database IDs in [mcp-integration.md](/Users/yjl/Desktop/PersonalOS/docs/setup/mcp-integration.md) once FlowUS MCP is connected.

## Day-to-Day Work

### Ingest from Raw Sources

Ask the agent:

```text
Process the most recent unprocessed Raw Source through FlowUS MCP and complete the ingest workflow.
```

The agent should:

```text
read the source
summarize it
update Raw Sources status
create or update Wiki Pages
link Questions or Outputs when needed
write a Log record
```

### WeRead to FlowUS

If WeRead MCP is available, use the dedicated workflow:

- Workflow: [weread-to-wiki.md](/Users/yjl/Desktop/PersonalOS/docs/workflows/weread-to-wiki.md)
- Script: [weread_flowus_pipeline.js](/Users/yjl/Desktop/PersonalOS/scripts/weread_flowus_pipeline.js)
- Project skill: [skills/weread-to-flowus-pipeline/SKILL.md](/Users/yjl/Desktop/PersonalOS/skills/weread-to-flowus-pipeline/SKILL.md)

Recommended prompt:

```text
Use the project skill $weread-to-flowus-pipeline to process "Book Title".
Start with a dry-run. If the result looks correct, write the records into FlowUS.
```

Direct script entrypoint:

```bash
node scripts/weread_flowus_pipeline.js ingest --title "Book Title"
node scripts/weread_flowus_pipeline.js ingest --title "Book Title" --apply
```

### Query

Ask the agent:

```text
Answer this question from my FlowUS knowledge base. If the answer has long-term value, write it back into Wiki Pages and Log.
```

### Lint

Run a periodic maintenance pass:

```text
Lint my FlowUS knowledge base for stale pages, orphan pages, unsupported claims, duplicate concepts, contradictions, and unresolved high-value questions.
```

## Recommended Reading Order

1. [docs/README.md](/Users/yjl/Desktop/PersonalOS/docs/README.md)
2. [AGENTS.md](/Users/yjl/Desktop/PersonalOS/AGENTS.md)
3. [schema.md](/Users/yjl/Desktop/PersonalOS/docs/specs/schema.md)
4. [mcp-integration.md](/Users/yjl/Desktop/PersonalOS/docs/setup/mcp-integration.md)
5. A workflow under [docs/workflows](/Users/yjl/Desktop/PersonalOS/docs/workflows)

## Design Choice

This repository is not a second knowledge base. It is the control plane around the FlowUS knowledge base:

- docs define the system
- data bootstraps the system
- scripts execute stable workflows
- skills help agents use those workflows consistently
