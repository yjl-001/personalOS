# FlowUS LLM Wiki Schema Contract

Use the local `docs/setup/mcp-integration.md` file for actual database IDs.

## Databases

### Raw Sources

Purpose: immutable source layer plus processing state.

Key fields:

- `标题`: title
- `类型`: select
- `来源链接`: url
- `作者`: rich_text
- `收集日期`: date
- `处理状态`: select, values `未处理`, `阅读中`, `已摘要`, `已入库`, `待复查`, `已归档`
- `主题标签`: multi_select
- `可信度`: select, values `高`, `中`, `低`, `未评估`
- `重要性`: number
- `摘要`: rich_text
- `关键摘录`: rich_text
- `关联 Wiki Pages`: relation to Wiki Pages
- `关联 Questions`: relation to Questions
- `处理记录`: rich_text
- `最后处理时间`: date

### Wiki Pages

Purpose: persistent synthesized knowledge pages.

Key fields:

- `页面名称`: title
- `页面类型`: select, values `概念`, `主题`, `人物`, `方法`, `案例`, `自我知识`, `决策`, `时间线`, `索引`
- `一句话摘要`: rich_text
- `成熟度`: select, values `草稿`, `初步成型`, `稳定`, `待重写`, `已废弃`
- `可信度`: select, values `高`, `中`, `低`, `混合`, `待验证`
- `领域`: multi_select
- `主题标签`: multi_select
- `相关资料`: relation to Raw Sources
- `相关问题`: relation to Questions
- `相关页面`: self-relation to Wiki Pages
- `最后更新`: date
- `推荐复查时间`: date
- `待验证点`: rich_text
- `更新摘要`: rich_text

### Questions

Purpose: high-value questions that drive knowledge growth.

Key fields:

- `问题`: title
- `状态`: select, values `未开始`, `探索中`, `已回答`, `持续更新`, `暂停`
- `问题类型`: select, values `研究`, `决策`, `自我理解`, `写作`, `项目`, `复盘`
- `优先级`: select, values `高`, `中`, `低`
- `当前答案`: rich_text
- `相关资料`: relation to Raw Sources
- `相关知识页`: relation to Wiki Pages
- `输出成果`: relation to Outputs
- `下一个问题`: rich_text
- `是否沉淀为 Wiki`: checkbox
- `创建日期`: date
- `最后更新`: date

### Outputs

Purpose: deliverables produced from the knowledge base.

Key fields:

- `标题`: title
- `类型`: select, values `文章`, `Memo`, `PPT`, `清单`, `方案`, `课程`, `图表`, `对话总结`
- `状态`: select, values `草稿`, `修改中`, `已完成`, `已发布`, `已归档`
- `来源问题`: relation to Questions
- `来源知识页`: relation to Wiki Pages
- `来源资料`: relation to Raw Sources
- `发布位置`: url
- `创建日期`: date
- `最后更新`: date
- `下一步动作`: rich_text

### Log

Purpose: chronological record of knowledge base evolution.

Key fields:

- `标题`: title
- `时间`: date
- `操作类型`: select, values `ingest`, `query`, `update`, `lint`, `output`, `review`, `system`
- `涉及资料`: relation to Raw Sources
- `涉及知识页`: relation to Wiki Pages
- `涉及问题`: relation to Questions
- `涉及输出`: relation to Outputs
- `主要变化`: rich_text
- `后续动作`: rich_text
- `操作者`: select, values `我`, `LLM`, `我+LLM`
