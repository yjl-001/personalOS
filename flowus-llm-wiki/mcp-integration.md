# FlowUS MCP Integration

这个文件用于把本地蓝图映射到实际 FlowUS MCP 能力。不同 Agent 或 MCP Server 暴露的工具名可能不同，所以这里写的是能力契约，不绑定具体工具名。

## 连接信息

FlowUS MCP 连接请以你实际使用的 FlowUS MCP 文档为准。常见形式会包含一个 token 化的 MCP server endpoint。

需要准备：

- FlowUS MCP token
- 根页面：`个人知识库 OS`
- 5 个核心数据库的 page/database id
- 字段名到字段 id 的映射

## Database ID Mapping

补全后让 Agent 使用这里的 ID，减少搜索成本。

| 逻辑名称 | FlowUS 名称 | FlowUS ID |
|---|---|---|
| root | 个人知识库 OS | TODO |
| dashboard | 00 Dashboard | TODO |
| raw_sources | Raw Sources | TODO |
| wiki_pages | Wiki Pages | TODO |
| questions | Questions | TODO |
| outputs | Outputs | TODO |
| log | Log | TODO |
| system_rules | 99 System / LLM 维护规则 | TODO |

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

