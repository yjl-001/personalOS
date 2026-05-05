# Relationship Guide

In this system, a “relationship” means a FlowUS relation field between database records.

## Basic Setup Pattern

In FlowUS, create relations with this mental model:

1. Open the source database, for example `Raw Sources`.
2. Add a new field.
3. Choose the field type `关联`.
4. Select the target database, for example `Wiki Pages`.
5. Name the field using the schema name, for example `关联 Wiki Pages`.
6. If FlowUS offers to create the reverse relation automatically, enable it and name the reverse field using the schema, for example `相关资料`.

If the current FlowUS UI does not offer reverse-relation creation, create the matching reverse field manually in the target database.

## Recommended Relation Pairs

Prefer creating the relation from the left-side table. If FlowUS auto-generates the reverse field, the right-side field will appear automatically.

| Create from | Field name | Target database | Reverse field |
|---|---|---|---|
| Raw Sources | 关联 Wiki Pages | Wiki Pages | 相关资料 |
| Raw Sources | 关联 Questions | Questions | 相关资料 |
| Wiki Pages | 相关页面 | Wiki Pages | 相关页面 |
| Wiki Pages | 相关问题 | Questions | 相关知识页 |
| Questions | 输出成果 | Outputs | 来源问题 |
| Outputs | 来源知识页 | Wiki Pages | optional: `相关输出` |
| Outputs | 来源资料 | Raw Sources | optional: `相关输出` |
| Log | 涉及资料 | Raw Sources | optional: `相关日志` |
| Log | 涉及知识页 | Wiki Pages | optional: `相关日志` |
| Log | 涉及问题 | Questions | optional: `相关日志` |
| Log | 涉及输出 | Outputs | optional: `相关日志` |

## How This Maps to the Checklist

The implementation checklist mentions many “two-way” relationships, for example:

```text
Raw Sources -> Wiki Pages
Wiki Pages -> Raw Sources
```

In practice, this is usually one relation pair:

```text
Raw Sources.关联 Wiki Pages -> Wiki Pages
reverse field: Wiki Pages.相关资料
```

If the reverse field already exists, do not create a second duplicate field.

## Minimum Required Relations

Build these in the first version:

- `Raw Sources.关联 Wiki Pages` -> `Wiki Pages`
- `Raw Sources.关联 Questions` -> `Questions`
- `Wiki Pages.相关页面` -> `Wiki Pages`
- `Wiki Pages.相关问题` -> `Questions`
- `Questions.输出成果` -> `Outputs`
- `Log.涉及资料` -> `Raw Sources`
- `Log.涉及知识页` -> `Wiki Pages`
- `Log.涉及问题` -> `Questions`
- `Log.涉及输出` -> `Outputs`

These can wait until later:

- `Outputs.来源知识页`
- `Outputs.来源资料`

Reason:

In the first version, `Outputs` can still find their upstream context through `来源问题`. Add direct links once outputs become frequent enough to justify the extra structure.

## Naming Advice

Use the schema field names as-is:

- in `Raw Sources`: `关联 Wiki Pages`, `关联 Questions`
- in `Wiki Pages`: `相关资料`, `相关问题`, `相关页面`
- in `Questions`: `相关资料`, `相关知识页`, `输出成果`
- in `Outputs`: `来源问题`, `来源知识页`, `来源资料`
- in `Log`: `涉及资料`, `涉及知识页`, `涉及问题`, `涉及输出`

Stable field names make MCP writes much easier for agents.

## Validation Method

After creating the relations, verify with a tiny test:

1. Create one test record in `Raw Sources`.
2. Create one test page in `Wiki Pages`.
3. Set `Raw Sources.关联 Wiki Pages` to the test Wiki Page.
4. Open the Wiki Page and confirm the test Raw Source appears in `相关资料`.
5. Create one `Log` record and link both the test Raw Source and the test Wiki Page.

If these links are navigable in both directions, the relation layer is working.
