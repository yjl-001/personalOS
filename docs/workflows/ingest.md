# Workflow: Ingest

Use this workflow to process one Raw Source and integrate it into `Wiki Pages`.

## User Prompt

```text
Process the most recent unprocessed Raw Source through FlowUS MCP and complete the ingest workflow.
```

You can also target a specific source:

```text
Process the Raw Source titled "..."
```

## Agent Steps

1. Query `Raw Sources` and locate the target record.
2. Read its properties and page body.
3. Search `Wiki Pages` for related pages.
4. Search `Questions` for related questions.
5. Generate a source summary.
6. Draft an update plan.
7. If more than 5 Wiki Pages would be affected, request confirmation first.
8. Execute the updates.
9. Write a `Log` entry.
10. Return a concise report.

## Summary Template

```text
### One-Sentence Conclusion

### Key Ideas

### Key Evidence

### Impact on the Existing Knowledge Base

### Pages To Create

### Pages To Update

### New Questions

### Disagreement / Uncertainty
```

## Update Rules

- Create a new Wiki Page when a concept is likely to recur.
- Keep one-off or low-value details inside the Raw Source summary.
- If new material changes an old page, update its current understanding and update history.
- If new material only adds support, append it under evidence or main sources.
- If it conflicts with an old conclusion, record it under disagreement or uncertainty instead of silently overwriting.

## Return Format

```text
Ingest completed:
- Source: "..."
- Created Wiki Pages:
- Updated Wiki Pages:
- Created Questions:
- Log written:

Things to notice:
-

Suggested next step:
-
```
