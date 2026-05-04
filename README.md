# FlowUS LLM Wiki Starter Kit

这是一个基于 FlowUS + LLM Agent + MCP 的个人知识库启动包。

它的目标不是把 FlowUS 变成一个传统笔记软件，而是把它设计成一个由 LLM 持续维护的个人知识库系统：

- 你负责收集资料、提出问题、判断方向。
- LLM 负责摘要、归档、交叉引用、更新旧页面、发现矛盾、写日志。
- FlowUS 负责承载结构化数据库、页面正文、关系视图和日常浏览。

核心原则：

> Raw Sources 保真，Wiki Pages 沉淀，Questions 驱动生长，Log 记录演化，Agent 通过 MCP 维护系统。

## 文件结构

```text
.
├── AGENTS.md
├── README.md
└── flowus-llm-wiki
    ├── dashboard.md
    ├── implementation-checklist.md
    ├── mcp-integration.md
    ├── post-mcp-fixes.md
    ├── relationship-guide.md
    ├── schema.md
    ├── test-report.md
    ├── import
    │   ├── log.csv
    │   ├── outputs.csv
    │   ├── questions.csv
    │   ├── raw-sources.csv
    │   └── wiki-pages.csv
    ├── seed
    │   ├── flowus-llm-wiki-seed.md
    │   ├── raw-source-llm-wiki-summary.md
    │   ├── wiki-page-flowus-personal-kb-os.md
    │   ├── wiki-page-llm-wiki.md
    │   └── llm-maintenance-rules-flowus-page.md
    ├── templates
    │   ├── lint-report.md
    │   ├── log-entry.md
    │   ├── output.md
    │   ├── question.md
    │   ├── raw-source.md
    │   └── wiki-page.md
    └── workflows
        ├── ingest.md
        ├── lint.md
        ├── query.md
        └── weekly-review.md
```

## FlowUS 中的最小系统

先只建 5 个数据库和 2 个系统页面：

```text
个人知识库 OS
├── 00 Dashboard
├── 01 Raw Sources
├── 02 Wiki Pages
├── 03 Questions
├── 04 Outputs
├── 05 Log
└── 99 System
    └── LLM 维护规则
```

不要一开始拆太细。Projects、Areas、Reviews 先用字段和视图承载，等数量变大后再独立成库。

## 快速开始

1. 在 FlowUS 创建一个根页面：`个人知识库 OS`。
2. 按 `flowus-llm-wiki/schema.md` 创建 5 个数据库。
3. 可选：用 `flowus-llm-wiki/import/*.csv` 导入种子数据。
4. 把 `flowus-llm-wiki/dashboard.md` 复制到 `00 Dashboard`。
5. 把 `flowus-llm-wiki/seed/llm-maintenance-rules-flowus-page.md` 复制到 `99 System / LLM 维护规则`。
6. 按 `flowus-llm-wiki/implementation-checklist.md` 做第一次验收。
7. 将 `AGENTS.md` 放在支持 Agent 的工作目录中，作为 Codex/Claude Code/OpenCode 等工具的系统约定。
8. 如果你的 Agent 已接入 FlowUS MCP，把 `flowus-llm-wiki/mcp-integration.md` 中的数据库映射补全。

## 日常工作流

### 收集

所有资料先进入 `Raw Sources`，状态设为 `未处理`。资料可以是文章、书、视频、播客、论文、网页、对话、日记或图片。

### Ingest

对 Agent 说：

```text
请通过 FlowUS MCP 处理 Raw Sources 里最近一条未处理资料，按 LLM 维护规则完成 ingest。
```

Agent 应该完成：

```text
读取资料
生成摘要
更新 Raw Sources 状态
新增或更新 Wiki Pages
关联 Questions / Outputs
写入 Log
```

### Query

对 Agent 说：

```text
基于我的 FlowUS 知识库，回答这个问题：……
如果答案有长期价值，请沉淀回 Wiki Pages，并写入 Log。
```

### Lint

每周或每月运行一次：

```text
请对我的 FlowUS 知识库做一次 lint，重点检查 stale pages、孤立页面、缺少来源的结论、重复概念、矛盾结论和值得继续研究的问题。
```

## 第一周落地目标

第一周只追求跑通闭环：

- 建好 5 个核心数据库。
- 导入或手动创建 8 个种子 Wiki Pages。
- 处理 3 条 Raw Sources。
- 让 Agent 回答 2 个 Questions。
- 至少把 1 个回答沉淀为 Wiki Page 或 Output。
- 跑一次 lint，检查结构是否顺手。

## 设计取舍

FlowUS 是知识库本体，不再需要默认维护一套本地 Markdown Wiki 作为中间层。

本地文件仍然有价值：它们是系统蓝图、Agent 协议、模板和备份。真正的知识资产应以 FlowUS 中的数据库和页面为准。
