# Implementation Checklist

这是一份按顺序执行的 FlowUS 搭建清单。目标是 60-90 分钟内搭出第一版，而不是一开始追求完美。

## Phase 1: 建根页面

- [ ] 创建根页面：`个人知识库 OS`
- [ ] 创建子页面：`00 Dashboard`
- [ ] 创建子页面：`99 System`
- [ ] 在 `99 System` 下创建页面：`LLM 维护规则`
- [ ] 将 `seed/llm-maintenance-rules-flowus-page.md` 复制进 `LLM 维护规则`
- [ ] 将 `dashboard.md` 复制进 `00 Dashboard`

## Phase 2: 建 5 个核心数据库

按 `schema.md` 创建：

- [ ] `Raw Sources`
- [ ] `Wiki Pages`
- [ ] `Questions`
- [ ] `Outputs`
- [ ] `Log`

每个数据库先只建规格中的字段，不要额外加字段。等跑完第一轮 ingest 后再改。

## Phase 3: 建关系字段

- [ ] `Raw Sources` 关联 `Wiki Pages`
- [ ] `Raw Sources` 关联 `Questions`
- [ ] `Wiki Pages` 关联 `Raw Sources`
- [ ] `Wiki Pages` 关联 `Questions`
- [ ] `Wiki Pages` 自关联 `Wiki Pages`
- [ ] `Questions` 关联 `Raw Sources`
- [ ] `Questions` 关联 `Wiki Pages`
- [ ] `Questions` 关联 `Outputs`
- [ ] `Outputs` 关联 `Questions`
- [ ] `Outputs` 关联 `Wiki Pages`
- [ ] `Outputs` 关联 `Raw Sources`
- [ ] `Log` 关联 `Raw Sources`
- [ ] `Log` 关联 `Wiki Pages`
- [ ] `Log` 关联 `Questions`
- [ ] `Log` 关联 `Outputs`

## Phase 4: 建视图

### Raw Sources

- [ ] 未处理
- [ ] 高价值
- [ ] 待复查
- [ ] 按类型
- [ ] 按主题

### Wiki Pages

- [ ] 全部知识页
- [ ] 概念地图
- [ ] 主题页
- [ ] 自我知识
- [ ] 待重写
- [ ] 待验证
- [ ] 近期更新
- [ ] 稳定知识

### Questions

- [ ] 正在探索
- [ ] 高优先级
- [ ] 待沉淀
- [ ] 已回答

### Outputs

- [ ] 草稿
- [ ] 已完成
- [ ] 按类型

### Log

- [ ] 最近日志
- [ ] Ingest
- [ ] Query
- [ ] Lint
- [ ] System

## Phase 5: 导入种子数据

可用 `import/*.csv` 导入，或手动创建：

- [ ] 导入 `raw-sources.csv`
- [ ] 导入 `wiki-pages.csv`
- [ ] 导入 `questions.csv`
- [ ] 导入 `outputs.csv`
- [ ] 导入 `log.csv`

CSV 导入通常不会自动创建数据库关系。导入后手动补关键关联即可。

## Phase 6: MCP 映射

如果 Agent 已经能调用 FlowUS MCP：

- [ ] 在 `mcp-integration.md` 记录根页面 ID
- [ ] 记录 5 个数据库 ID
- [ ] 记录关键字段 ID
- [ ] 用一个测试资料跑通：
  - [ ] 查询未处理 Raw Source
  - [ ] 更新摘要字段
  - [ ] 新建 Wiki Page
  - [ ] 建立关联
  - [ ] 更新处理状态
  - [ ] 写入 Log

## Phase 7: 第一次真实使用

添加 3 条资料：

- [ ] 一篇文章
- [ ] 一个你自己的问题或想法
- [ ] 一段对话或读书摘录

然后让 Agent 执行：

```text
请通过 FlowUS MCP 处理 Raw Sources 里最近一条未处理资料，按 LLM 维护规则完成 ingest。
```

验收标准：

- [ ] Raw Source 状态从 `未处理` 变成 `已入库`
- [ ] 至少新增或更新 1 个 Wiki Page
- [ ] 至少产生 1 个后续 Question
- [ ] Log 中有一条 ingest 记录
- [ ] Dashboard 能看到最新变化

## Phase 8: 一周后再改系统

第一周先不要重构。只记录摩擦：

- 哪些字段没用上？
- 哪些字段不够？
- 哪些页面模板太长？
- 哪些视图最常打开？
- Agent 哪一步最容易出错？

一周后再做一次 schema 调整。

