# Workflow: Query

Use this workflow to answer from the FlowUS knowledge base and write back durable answers when appropriate.

## User Prompt

```text
Answer this question from my FlowUS knowledge base. If the answer has long-term value, write it back into Wiki Pages and Log.
```

## Agent Steps

1. Search `Questions` to see whether a similar question already exists.
2. Search `Wiki Pages` and read the relevant pages.
3. Search `Raw Sources` and read the necessary supporting sources.
4. Generate the answer and make these parts explicit:
   - current conclusion
   - supporting evidence
   - counter-evidence
   - uncertainty
   - recommended action
5. Decide whether to write back:
   - create or update a `Question`
   - create or update a `Wiki Page`
   - create an `Output` if the answer becomes a deliverable
6. Execute the write-back.
7. Write a `Log` entry.

## Answer Format

```text
## Current Conclusion

## Evidence

## Uncertainty

## Recommended Action

## Written Back Into The Knowledge Base

## Follow-Up Questions
```

## Write-Back Criteria

Answers are worth writing back when they:

- have high reuse value
- change an existing judgment
- connect multiple sources or pages
- form a method, framework, decision, or output draft

Answers do not always need write-back when they are:

- one-off factual lookups
- unrelated to the knowledge base themes
- explicitly requested as temporary answers only
