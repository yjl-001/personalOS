# Workflow: Lint

用于检查知识库健康度。

## 用户指令

```text
请对我的 FlowUS 知识库做一次 lint，检查 stale pages、孤立页面、缺少来源的结论、重复概念、矛盾结论和值得继续研究的问题。
```

## Agent 步骤

1. 读取最近 20 条 `Log`。
2. 查询 `Wiki Pages`：
   - 最后更新时间
   - 成熟度
   - 可信度
   - 关联资料数量
   - 关联问题数量
   - 相关页面数量
3. 查询 `Raw Sources`：
   - 未处理资料
   - 待复查资料
   - 高重要性但未入库资料
4. 查询 `Questions`：
   - 高优先级未回答
   - 当前答案不为空但未沉淀
5. 识别问题并生成报告。
6. 创建 `Outputs` 中的 Lint Report，或在 `Log` 写入摘要。

## 检查项

### Stale Pages

稳定或高价值页面超过 30-90 天未更新，且仍与当前问题相关。

### Orphan Pages

没有相关资料、相关问题、相关页面的 Wiki Pages。

### Unsupported Claims

页面里有强结论，但没有关联 Raw Sources 或支持证据。

### Duplicate Concepts

名称不同但内容高度重合的页面。

### Contradictions

多个页面对同一问题给出冲突结论。

### Missing Pages

Raw Sources 或 Questions 中频繁出现，但还没有独立 Wiki Page 的概念。

### Unresolved Questions

高优先级、长期未回答或反复出现的问题。

## 输出格式

```text
## 本次健康度结论

## 需要修复的页面

## 建议新建的页面

## 建议合并或废弃的页面

## 缺少来源的结论

## 下周最值得研究的问题

## 已写入 Log
```

