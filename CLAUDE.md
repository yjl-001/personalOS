
This is a **FlowUS LLM Wiki Starter Kit** — a personal knowledge base system where FlowUS hosts structured databases and pages, and an LLM agent (via FlowUS MCP) maintains them. It is not a traditional software project with build/test/deploy cycles.

## Architecture

```
PersonalOS/
├── AGENTS.md              # System prompt for the FlowUS wiki maintenance agent
├── README.md              # User-facing project overview and quick-start
├── flowus-llm-wiki/       # Blueprint, schema, templates, workflows, seed data
│   ├── schema.md          # 5 database specs (Raw Sources, Wiki Pages, Questions, Outputs, Log)
│   ├── mcp-integration.md # Live database IDs, field mappings, MCP capabilities, tested behaviors
│   ├── implementation-checklist.md  # First-time setup verification
│   ├── relationship-guide.md        # Cross-database relation rules
│   ├── test-report.md              # MCP smoke test results
│   ├── post-mcp-fixes.md           # Known schema drift between spec and live databases
│   ├── templates/         # Markdown templates for each record type
│   ├── workflows/         # ingest.md, lint.md, query.md, weekly-review.md
│   ├── seed/              # Seed pages for initial knowledge base population
│   └── import/            # CSV seed data for database import
└── skills/flowus-mcp-wiki/ # Claude Code skill for operating FlowUS MCP
    ├── SKILL.md           # Skill definition and workflows
    ├── agents/openai.yaml # OpenAI-compatible agent config
    ├── references/        # MCP patterns, schema contracts, tested behaviors
    └── scripts/flowus_mcp_smoke.rb  # FlowUS MCP validation script
```

## The 5-Database System

FlowUS hosts 5 core databases under a root page `个人知识库 OS`:

- **Raw Sources** → unprocessed materials (articles, books, videos, papers)
- **Wiki Pages** → synthesized knowledge pages (concepts, methods, decisions)
- **Questions** → driving exploration; knowledge grows around questions, not collections
- **Outputs** → deliverables produced from the knowledge base
- **Log** → time-series record of every agent operation

Database IDs and field mappings are in `flowus-llm-wiki/mcp-integration.md`. Schema definitions are in `flowus-llm-wiki/schema.md`.

## Working With This Repo

This repo has no build step, no package manager, and no test suite (other than the FlowUS MCP smoke script). The primary "development" activities are:

- **Editing AGENTS.md**: the system prompt that governs agent behavior. Changes here affect how future agents ingest, query, lint, and maintain the knowledge base.
- **Updating schema.md / mcp-integration.md**: when FlowUS database fields change or IDs need updating.
- **Refining workflows**: the markdown files in `flowus-llm-wiki/workflows/`.
- **Smoke testing FlowUS MCP**: `ruby skills/flowus-mcp-wiki/scripts/flowus_mcp_smoke.rb db-audit` or `e2e-test`.

## AGENTS.md vs CLAUDE.md

- `AGENTS.md` is the **product** — it is deployed as the system prompt to LLM agents that maintain the FlowUS knowledge base. When editing it, follow the established structure: Canonical System → Operating Principles → Database Contract → Workflows → Safe Update Rules → Write Patterns.
- `CLAUDE.md` (this file) is for Claude Code to understand how to work on the repo itself.

## FlowUS MCP Skill

The skill at `skills/flowus-mcp-wiki/` is invoked via `/flowus-mcp-wiki`. It provides stable write patterns (3-step: create title-only, update properties, put markdown), query strategies, relationship rules, and ingest/query/lint workflows. When Claude Code needs to interact with FlowUS, invoke this skill rather than calling MCP tools raw.

## Key Design Rules (from AGENTS.md)

- Raw Sources are immutable truth; Wiki Pages are evolvable synthesis.
- Always cross-reference and consider reverse impacts, not just single-page writes.
- New evidence that challenges old conclusions must be noted in the relevant Wiki Page.
- Preview large changes (>5 pages, stable-page rewrites, merges, deprecations) before executing.
- Never delete pages; mark maturity as `已废弃` with a reason.
- Every meaningful operation writes a Log entry.
