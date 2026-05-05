# 00 Dashboard

This is the home page of the Personal Knowledge OS. It should function as a control panel, not as decoration.

## Daily Entry Points

- Quick capture: send new ideas, new questions, and new materials into `Raw Sources` or `Questions`.
- Pending materials: embed the `Raw Sources / 未处理` view.
- Active questions: embed the `Questions / 正在探索` view.
- Recently updated knowledge pages: embed the `Wiki Pages / 近期更新` view.

## Knowledge Map

Embed a few `Wiki Pages` views:

- concept map
- topic pages
- self-knowledge
- pending verification
- stable knowledge

## Current Questions

Embed `Questions` views:

- high priority
- ready to synthesize
- answered

## Output Pipeline

Embed `Outputs` views:

- drafts
- completed
- grouped by type

## Recent Log

Embed `Log / 最近日志` and show the latest 10 entries.

## System Maintenance

Keep fixed links to:

- `99 System / LLM 维护规则`
- `Raw Sources`
- `Wiki Pages`
- `Questions`
- `Outputs`
- `Log`

## Weekly Prompt

Run at least once per week:

```text
Please run a weekly review on my knowledge base through FlowUS MCP:
1. process the most valuable un-ingested materials
2. review questions that are ready for synthesis
3. identify Wiki Pages that still need verification
4. suggest the 3 best questions to study next week
5. write a Log entry
```
