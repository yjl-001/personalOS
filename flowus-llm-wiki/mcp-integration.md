# FlowUS MCP Integration

这个文件用于把本地蓝图映射到实际 FlowUS MCP 能力。不同 Agent 或 MCP Server 暴露的工具名可能不同，所以这里写的是能力契约，不绑定具体工具名。

## 连接信息

FlowUS MCP 连接请以你实际使用的 FlowUS MCP 文档为准。常见形式会包含一个 token 化的 MCP server endpoint。

需要准备：

- FlowUS MCP token
- 根页面：`个人知识库 OS`
- 5 个核心数据库的 page/database id
- 字段名到字段 id 的映射

## How To Get Page/Table IDs

FlowUS 的页面和多维表一般都可以通过“复制链接”拿到 ID。多维表本身也是一个页面级对象，所以很多工具会把多维表 ID 称为 `tablePageId`。

### 推荐方法：从链接提取

1. 在 FlowUS 网页端打开目标页面或目标多维表。
2. 点击右上角分享/更多菜单，选择复制链接。
3. 把链接粘贴到临时文本里。
4. 找链接中的 UUID，一般长得像：

```text
df7cd54f-1c21-4fc1-9fd8-ce81be1918a5
```

5. 这个 UUID 就是页面 ID 或多维表的 `tablePageId`。

常见链接形态：

```text
https://flowus.cn/share/df7cd54f-1c21-4fc1-9fd8-ce81be1918a5
https://flowus.cn/xxx/df7cd54f-1c21-4fc1-9fd8-ce81be1918a5
```

如果链接里带查询参数，例如：

```text
https://flowus.cn/share/df7cd54f-1c21-4fc1-9fd8-ce81be1918a5?code=...
```

只取 `?` 前面的 UUID。

### 页面 ID vs 多维表 ID

- 普通页面：复制该页面链接，提取 UUID。
- 页面级多维表：打开该多维表页面，复制链接，提取 UUID。这个就是 `tablePageId`。
- 多维表中的某一行记录：打开该行记录页面，复制链接，提取 UUID。这个是记录页面 ID，不是表 ID。

本系统需要优先记录的是 5 个多维表页面的 ID：

- `Raw Sources`
- `Wiki Pages`
- `Questions`
- `Outputs`
- `Log`

### 验证方法

如果你不确定取的是不是表 ID：

1. 把这个 ID 填到 `Database ID Mapping`。
2. 用 FlowUS MCP 尝试查询该数据库。
3. 如果能返回表字段或记录，就是正确的多维表 ID。
4. 如果返回的是普通页面内容，说明你复制到了普通页面 ID。
5. 如果 404 或无权限，检查 ID 是否复制错，或 MCP token 是否有该页面权限。

## Database ID Mapping

补全后让 Agent 使用这里的 ID，减少搜索成本。

注意：你从 FlowUS 复制多维表链接时，可能得到 `页面ID#片段ID`。大多数 API/MCP 参数需要的是单独的 UUID，而不是完整的 `UUID#UUID`。本表先把 `#` 前后的 ID 拆开保存。

| 逻辑名称 | FlowUS 名称 | 优先使用的 Page/Table ID | URL fragment / view/block ID 备查 |
|---|---|---|---|
| root | 个人知识库 OS | a548f75d-3010-45d8-8fc1-6baae0f77695 |  |
| dashboard | 00 Dashboard | 49d67329-1763-4db7-96e5-f748af920ed6 |  |
| raw_sources | Raw Sources | 39e9ec92-a952-4ec8-9db0-45adee987a58 | 308f70cb-6d0d-4810-ab02-68cb47e49ffa |
| wiki_pages | Wiki Pages | 9988c8c6-ceed-4eba-9bc8-5d9d96b303d6 | be040857-3dec-441c-99ae-1967de0ef12a |
| questions | Questions | 015944ff-f203-4370-bae8-ed2483c06cda | d2e034cb-e655-407b-a59b-fd649dd2d9ff |
| outputs | Outputs | 1a04b51b-6d35-4eef-82ed-1aac30908482 | 9f441956-22b6-4925-b988-07de704da4be |
| log | Log | 20d39f53-8c09-4dc6-975b-5fffd5418e1d | b2781d5a-5514-4206-b917-35eaed90ec05 |
| system_rules | 99 System / LLM 维护规则 | 0c9e3c6a-3780-42d6-8946-5facf82eeeda |  |

接入 MCP 时，先用 `优先使用的 Page/Table ID` 测试查询多维表。如果 MCP 返回“不是表”“找不到表”或只能读取普通页面内容，再测试 `URL fragment / view/block ID`。

## Required MCP Capabilities

Agent 至少需要这些能力：

| 能力 | 用途 |
|---|---|
| search pages | 搜索 Wiki Pages、Questions、Raw Sources |
| query database | 按状态、日期、标签筛选记录 |
| read page blocks | 读取页面正文 |
| create page | 新建 Wiki Page、Question、Output |
| update page properties | 更新数据库字段 |
| append blocks | 在页面正文追加摘要、更新记录、证据 |
| replace or patch blocks | 修订 Wiki Page 的当前理解 |
| create relation | 建立资料、问题、知识页、输出之间的关联 |

如果 MCP 不支持块级 patch，就采用保守策略：追加 `更新记录`，并在页面顶部更新摘要字段，避免破坏原内容。

## Safe Write Strategy

### 小更新直接写

- 单条 Raw Source 状态更新。
- 单个 Wiki Page 新建。
- 单个 Question 新建。
- 单条 Log 写入。
- 在已有页面追加更新记录。

### 大更新先预览

- 一次影响超过 5 个页面。
- 改写稳定页面的核心结论。
- 合并页面。
- 废弃页面。
- 修改数据库字段或标签体系。

预览格式：

```text
本次计划修改：
- Raw Sources: 1 条
- Wiki Pages: 新增 2 条，更新 4 条
- Questions: 新增 1 条
- Log: 新增 1 条

需要确认的风险：
- 将改写稳定页面《...》的核心结论
- 将合并《...》和《...》
```

## Field ID Mapping Template

实际接入后，建议补一个 JSON 或表格：

```json
{
  "raw_sources": {
    "标题": "TODO",
    "类型": "TODO",
    "处理状态": "TODO",
    "摘要": "TODO",
    "关联 Wiki Pages": "TODO"
  },
  "wiki_pages": {
    "页面名称": "TODO",
    "页面类型": "TODO",
    "一句话摘要": "TODO",
    "成熟度": "TODO",
    "相关资料": "TODO"
  }
}
```

## Agent Test Checklist

接入 FlowUS MCP 后，先用一个测试资料跑通闭环：

1. 查询 `Raw Sources` 中 `处理状态 = 未处理` 的记录。
2. 读取该记录页面正文。
3. 更新摘要字段。
4. 新建一个 `Wiki Pages` 记录。
5. 建立 Raw Source 到 Wiki Page 的关联。
6. 更新 Raw Source 的处理状态为 `已入库`。
7. 新建一条 `Log`。
8. 回读这些记录，确认关系正确。

## Tested Behavior Notes

2026-05-04 的实测结果：

- MCP endpoint 和 token 可用。
- `API-getMe` 返回的权限包含 pages、blocks、databases、search 的 read/write。
- `API-getDatabase` 可以读取 5 个核心多维表的 schema。
- `API-createPage` 可以在多维表中创建记录。
- 更稳定的创建策略是：先只用标题创建记录，再用 `API-updatePage` 写入其他属性。
- `API-updatePage` 可以更新 select、multi_select、rich_text、number、date、url、relation。
- 双向 relation 可用，反向字段能回读到。
- `API-putMarkdown` 和 `API-getMarkdown` 可用于页面正文写入和回读。
- `API-search` 可以找到 MCP 创建的页面。
- `API-queryDatabase` 可以查询已有可见记录，但对 MCP 刚创建的记录没有稳定返回；Agent 查询自己刚创建的页面时应优先使用 `API-search` 或已保存的 page id。
- `Wiki Pages.相关页面` 这种同表自关联可以写入，但 MCP 不应依赖自动反向回填；Agent 应显式双边写入。

### Practical Write Pattern

不要把大量属性一次性塞进 `API-createPage`。推荐：

```text
1. API-createPage
   - parent.database_id
   - only title property

2. API-updatePage
   - select / rich_text / number / date / url / relation

3. API-putMarkdown
   - write page body

4. API-getPage / API-search
   - verify properties and relations
```

### Self-Relation Pattern

当需要建立 `Wiki Pages` 内部的页面关联时：

```text
1. 更新 A.相关页面 = [B]
2. 更新 B.相关页面 = [A]
3. 分别 API-getPage 回读 A 和 B
```

不要只写一边后等待 FlowUS MCP 自动回填另一边。

### Current Schema Differences

实测发现当前 FlowUS 表结构和 `schema.md` 有少量命名差异：

- `Raw Sources`: 当前字段是 `关键摘要`，schema 期望 `关键摘录`。
- `Wiki Pages`: 缺少自关联字段 `相关页面`。
- `Wiki Pages`: `主题标签` 当前是 `rich_text`，schema 期望 `multi_select`。
- `Log`: 当前字段是 `涉及知识库`，schema 期望 `涉及知识页`。
- `Raw Sources.处理状态` 中有一个多余选项 `2026-04-29`。

这些不阻断 Agent 工作，但建议后续统一命名，减少维护时的条件分支。
