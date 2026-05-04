# Relationship Guide

Phase 3 的“关联”指 FlowUS 多维表中的关联字段。它用来把一张表中的记录连接到另一张表中的记录。

## 基本操作

在 FlowUS 中一般按这个思路操作：

1. 打开源多维表，例如 `Raw Sources`。
2. 点击表格右侧 `+` 添加字段，或点击字段菜单新增字段。
3. 字段类型选择 `关联`。
4. 选择目标多维表，例如 `Wiki Pages`。
5. 字段命名为 schema 中的字段名，例如 `关联 Wiki Pages`。
6. 如果 FlowUS 提示是否在目标表创建反向关联，选择创建，并把反向字段命名为目标表中的字段名，例如 `相关资料`。

如果 FlowUS 当前界面没有反向关联选项，就在目标表里手动再建一个关联字段。

## 推荐按这些关系创建

优先从左侧表发起创建。如果能自动生成反向字段，右侧字段会一起出现。

| 从哪个表创建 | 字段名 | 关联到 | 反向字段名 |
|---|---|---|---|
| Raw Sources | 关联 Wiki Pages | Wiki Pages | 相关资料 |
| Raw Sources | 关联 Questions | Questions | 相关资料 |
| Wiki Pages | 相关页面 | Wiki Pages | 相关页面 |
| Wiki Pages | 相关问题 | Questions | 相关知识页 |
| Questions | 输出成果 | Outputs | 来源问题 |
| Outputs | 来源知识页 | Wiki Pages | 可选：相关输出 |
| Outputs | 来源资料 | Raw Sources | 可选：相关输出 |
| Log | 涉及资料 | Raw Sources | 可选：相关日志 |
| Log | 涉及知识页 | Wiki Pages | 可选：相关日志 |
| Log | 涉及问题 | Questions | 可选：相关日志 |
| Log | 涉及输出 | Outputs | 可选：相关日志 |

## 和 checklist 的对应关系

Phase 3 里写了很多双向关系，例如：

```text
Raw Sources 关联 Wiki Pages
Wiki Pages 关联 Raw Sources
```

这其实是一组关系。建法是：

```text
Raw Sources.关联 Wiki Pages -> Wiki Pages
反向字段：Wiki Pages.相关资料
```

所以如果反向字段已经出现，不要再手动创建第二个重复字段。

## 最小必建关系

第一版必须建：

- `Raw Sources.关联 Wiki Pages` -> `Wiki Pages`
- `Raw Sources.关联 Questions` -> `Questions`
- `Wiki Pages.相关页面` -> `Wiki Pages`
- `Wiki Pages.相关问题` -> `Questions`
- `Questions.输出成果` -> `Outputs`
- `Log.涉及资料` -> `Raw Sources`
- `Log.涉及知识页` -> `Wiki Pages`
- `Log.涉及问题` -> `Questions`
- `Log.涉及输出` -> `Outputs`

第一版可以暂缓：

- `Outputs.来源知识页`
- `Outputs.来源资料`

原因是 Outputs 可以先通过 `来源问题` 找到上游资料和知识页。等你开始高频输出文章、方案、PPT 后，再补直接关系。

## 命名建议

尽量使用 schema 中的字段名：

- Raw Sources 里叫 `关联 Wiki Pages`、`关联 Questions`
- Wiki Pages 里叫 `相关资料`、`相关问题`、`相关页面`
- Questions 里叫 `相关资料`、`相关知识页`、`输出成果`
- Outputs 里叫 `来源问题`、`来源知识页`、`来源资料`
- Log 里叫 `涉及资料`、`涉及知识页`、`涉及问题`、`涉及输出`

字段名保持稳定，后续 Agent 通过 MCP 写入时会更省事。

## 验收方法

建完关系后，用一个测试记录确认：

1. 在 `Raw Sources` 新建一条测试资料。
2. 在 `Wiki Pages` 新建一条测试知识页。
3. 在 `Raw Sources.关联 Wiki Pages` 中选中测试知识页。
4. 打开测试知识页，确认 `相关资料` 能看到这条 Raw Source。
5. 在 `Log` 新建一条日志，并关联测试资料和测试知识页。

如果这些都能双向跳转，Phase 3 就算跑通。

