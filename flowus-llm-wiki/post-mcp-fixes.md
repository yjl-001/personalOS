# Post-MCP Fixes

这是 2026-05-04 FlowUS MCP 端到端测试后建议修正的地方。它们不是全部阻断项，但修完后 Agent 维护会更稳定、更少写条件分支。

## P0: 建议马上改

### 1. `Wiki Pages` 增加自关联字段 `相关页面`

当前状态：缺少字段。

修改方式：

- 打开 `Wiki Pages` 多维表。
- 新增字段：`相关页面`
- 字段类型：关联
- 关联对象：`Wiki Pages` 自己
- 连接方式：双向连接

原因：

Wiki 页面之间需要互相连接，例如 `LLM Wiki` 关联 `RAG`、`FlowUS MCP`、`个人知识库 OS`。没有这个字段，Agent 只能关联资料和问题，知识网络会少一层横向连接。

### 2. `Log` 字段 `涉及知识库` 改名为 `涉及知识页`

当前状态：字段存在，但名字和 schema 不一致。

修改方式：

- 打开 `Log` 多维表。
- 找到字段：`涉及知识库`
- 改名为：`涉及知识页`

原因：

这个字段实际关联的是 `Wiki Pages`，叫 `涉及知识页` 更准确，也和 schema / Agent 规则一致。

## P1: 建议本周改

### 3. `Raw Sources` 字段 `关键摘要` 改名为 `关键摘录`

当前状态：字段存在，但名字和 schema 不一致。

修改方式：

- 打开 `Raw Sources` 多维表。
- 找到字段：`关键摘要`
- 改名为：`关键摘录`

原因：

这个字段的用途是保存原文摘录、时间戳、引用片段，不是保存摘要。摘要已经有独立字段 `摘要`。

### 4. `Wiki Pages` 的 `主题标签` 改成多选字段

当前状态：`主题标签` 是 `rich_text` 文本字段。

建议目标：

- 字段名：`主题标签`
- 字段类型：多选

原因：

标签需要筛选、分组和视图过滤。文本字段不适合做标签体系，也不利于 Agent 稳定写入。

注意：

FlowUS 通常不能直接把已有字段从文本无损转换为多选。稳妥做法：

1. 新建字段：`主题标签 2`
2. 类型选择：多选
3. 手动或让 Agent 迁移已有标签
4. 删除旧 `主题标签`
5. 把 `主题标签 2` 改名为 `主题标签`

如果当前还没有多少数据，可以直接删旧字段重建。

### 5. 删除 `Raw Sources.处理状态` 里的错误选项 `2026-04-29`

当前状态：`处理状态` 单选里多了一个日期选项。

修改方式：

- 打开 `Raw Sources`
- 打开字段 `处理状态` 的选项设置
- 删除选项：`2026-04-29`

原因：

这应该是 CSV 导入或粘贴时误生成的选项。保留它会让 Agent 或你自己选择状态时混淆。

## P2: 可以稍后改

### 6. 清理 MCP 测试记录

测试记录标题都带：

```text
MCP E2E
```

建议清理：

- `MCP E2E Minimal Raw Source`
- `MCP E2E Query Visible Raw Source`
- `MCP E2E Test 20260504132654 ...`
- `MCP E2E Test 20260504133005 ...`

这些记录分布在：

- `Raw Sources`
- `Wiki Pages`
- `Questions`
- `Outputs`
- `Log`

删除属于云端数据删除，建议你在 FlowUS 里手动筛选后删除。

### 7. 保留 MCP 测试脚本和报告

本地这些文件建议保留：

- `flowus-llm-wiki/tools/flowus_mcp_smoke.rb`
- `flowus-llm-wiki/test-report.md`
- `flowus-llm-wiki/mcp-integration.md`

原因：

以后 FlowUS MCP 或 schema 变更后，可以重新跑 smoke test。

## 不需要改的地方

### 1. 5 个多维表 ID

`#` 前面的 UUID 已验证是正确的 table/database ID。

### 2. 双向关联

核心双向关联已经可用，测试中已验证：

- Raw Source -> Wiki Page
- Raw Source -> Question
- Wiki Page -> Raw Source
- Question -> Wiki Page
- Output -> Question
- Log -> Raw Source

### 3. MCP 权限

MCP integration 已有必要权限：

- pages read/write
- blocks read/write
- databases read/write
- search read

## Agent 工作流调整

后续让 Agent 写 FlowUS 时，使用这个稳定模式：

```text
1. API-createPage：只创建标题
2. API-updatePage：写字段和关联
3. API-putMarkdown：写正文
4. API-getPage / API-search：回读验证
```

不要让 Agent 在 `API-createPage` 里一次性写大量字段。

查询策略：

```text
查用户已有记录：可以用 API-queryDatabase
查 Agent 刚创建记录：优先用 API-search 或保存的 page id
```

## 推荐修正顺序

1. 在 `Wiki Pages` 新增 `相关页面` 自关联。
2. 把 `Log.涉及知识库` 改成 `涉及知识页`。
3. 把 `Raw Sources.关键摘要` 改成 `关键摘录`。
4. 把 `Wiki Pages.主题标签` 改成多选。
5. 删除 `Raw Sources.处理状态` 里的 `2026-04-29`。
6. 筛选并删除 `MCP E2E` 测试记录。

