# Workflow: Weekly Review

用于每周维护知识库节奏，让系统持续生长。

## 用户指令

```text
请通过 FlowUS MCP 对我的知识库做一次 weekly review。
```

## Agent 步骤

1. 读取最近 7 天 `Log`。
2. 查询最近 7 天新增或更新的 `Raw Sources`、`Wiki Pages`、`Questions`、`Outputs`。
3. 检查是否有：
   - 高价值未处理资料
   - 已回答但未沉淀的问题
   - 待验证知识页
   - 可输出主题
4. 给出一份周报。
5. 写入 `Log`，必要时创建 `Outputs` 记录。

## 周报格式

```text
## 本周知识库变化

## 新增资料

## 新增或更新知识页

## 关键认知变化

## 未解决问题

## 下周优先处理

## 可输出主题
```

