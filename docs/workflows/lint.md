# Workflow: Lint

Use this workflow to audit the health of the knowledge base.

## User Prompt

```text
Run a lint pass on my FlowUS knowledge base. Check stale pages, orphan pages, unsupported claims, duplicate concepts, contradictory conclusions, and valuable unresolved questions.
```

## Agent Steps

1. Read the latest 20 `Log` entries.
2. Query `Wiki Pages` for:
   - latest update time
   - maturity
   - confidence
   - number of related sources
   - number of related questions
   - number of related pages
3. Query `Raw Sources` for:
   - unprocessed materials
   - review-needed materials
   - high-importance materials not yet ingested
4. Query `Questions` for:
   - unanswered high-priority questions
   - questions that already have an answer but have not been synthesized
5. Identify the issues and generate a report.
6. Write the result into an `Output` lint report or summarize it in `Log`.

## Checks

### Stale Pages

Stable or high-value pages that have not been updated in 30 to 90 days but still matter.

### Orphan Pages

Wiki Pages with no related sources, no related questions, and no related pages.

### Unsupported Claims

Pages that contain strong conclusions without linked sources or supporting evidence.

### Duplicate Concepts

Different pages with highly overlapping meaning.

### Contradictions

Multiple pages that give conflicting answers to the same issue.

### Missing Pages

Concepts that appear repeatedly in `Raw Sources` or `Questions` but still have no dedicated Wiki Page.

### Unresolved Questions

High-priority questions that remain unanswered for a long time or keep returning.

## Output Format

```text
## Overall Health

## Pages That Need Repair

## Pages Worth Creating

## Pages Worth Merging or Retiring

## Unsupported Claims

## Best Questions To Research Next Week

## Logged Back Into The System
```
