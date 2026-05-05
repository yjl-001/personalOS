# CLAUDE.md

This repository is an operations layer for a FlowUS-based personal knowledge system. It is not a conventional software project with build, test, and deploy loops.

## What Matters Here

- `AGENTS.md` is the main operating contract for knowledge-base agents.
- `docs/` contains canonical architecture, setup notes, specs, and workflows.
- `data/` contains seed content, import CSVs, and writing templates.
- `scripts/` contains reusable execution entrypoints.
- `skills/` contains project-local Codex skills.
- `diagnostics/` contains audits, cleanup scripts, and real-flow verification tools.

## Current Repository Layout

```text
PersonalOS/
├── AGENTS.md
├── CLAUDE.md
├── README.md
├── docs/
│   ├── architecture/
│   ├── references/
│   ├── setup/
│   ├── specs/
│   └── workflows/
├── data/
│   ├── imports/
│   ├── seed/
│   └── templates/
├── scripts/
│   ├── flowus_mcp_smoke.rb
│   └── weread_flowus_pipeline.js
├── diagnostics/
│   ├── cleanup_flowus_records.rb
│   ├── lint_flowus_wiki.rb
│   └── real_ingest_flowus.rb
└── skills/
    ├── flowus-mcp-wiki/
    └── weread-to-flowus-pipeline/
```

## High-Value Files

- Schema: `docs/specs/schema.md`
- Live IDs and MCP mapping: `docs/setup/mcp-integration.md`
- First-time setup check: `docs/setup/implementation-checklist.md`
- WeRead workflow: `docs/workflows/weread-to-wiki.md`
- FlowUS MCP smoke script: `scripts/flowus_mcp_smoke.rb`
- WeRead pipeline script: `scripts/weread_flowus_pipeline.js`

## How To Work On This Repo

Typical work here is one of:

- refining `AGENTS.md`
- updating schema or integration docs after FlowUS changes
- improving workflows under `docs/workflows/`
- strengthening scripts in `scripts/`
- improving project-local skills in `skills/`
- running diagnostics against the live FlowUS setup

## Agent Guidance

- Treat `AGENTS.md` as the product contract, not just documentation.
- Prefer updating root entry docs and indexes when the structure changes.
- Keep paths stable and explicit. This repo is designed to be read by humans and agents.
- When adding reusable automation, prefer `scripts/` over one-off root files.
- When adding operating knowledge, prefer `docs/` or `skills/` instead of scattering notes.

## Validation Commands

From the project root:

```bash
ruby scripts/flowus_mcp_smoke.rb db-audit
ruby scripts/flowus_mcp_smoke.rb e2e-test
node --check scripts/weread_flowus_pipeline.js
```
