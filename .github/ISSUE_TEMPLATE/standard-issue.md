---
name: 标准 Issue
about: 按项目 Style Guide 创建架构、功能、技术或 Epic Issue
title: ''
labels: ''
assignees: ''
---

<!--
STYLE GUIDE
===========

语言
----
1. Issue 标题与正文说明使用中文。
2. 正式代码实体保留原始英文名，并使用反引号标识，例如：`GameManager`、`GameState`、`RuntimeMode`、`WorldManager`、`start_game()`。
3. 非代码架构术语优先使用中文，不写中英混合的 architecture prose。
   - authority gateway → 权威入口
   - runtime binding → 运行时绑定
   - public state / facts → 公共状态
   - state mutation → 状态修改
   - runtime graph → 运行时对象图 / 运行时对象引用
   - snapshot → 状态快照
   - smoke test → 冒烟测试
4. `Seed` 这类非正式代码实体在正文中写“随机种子”；具体字段仍写 `seed` / `game_seed`。
5. 不为了纯中文翻译代码类型名。Issue 中使用的名称应尽量与代码可搜索名称保持一致。

标题
----
1. 推荐格式：`核心代码概念` + 中文功能描述。
   - GameManager 生命周期与权威入口
   - GameState 与 PlayerState 公共状态模型
   - GameFlow 框架与 NormalGameFlow
   - 游戏启动、随机种子与 StartingLoadoutDef
2. Epic 可以保留 Roadmap / Feature 英文名称，并使用：
   - Game Foundation：游戏基础框架
3. 避免在标题中混用 and / & / 中文连接词。

Markdown 层级
-------------
1. GitHub Issue Title 已经是页面 H1，正文禁止使用 `#`。
2. 正文主要章节使用 `##`。
3. 设计方案内部子章节使用 `###`。
4. 原则上禁止 `####`；如果需要第四层标题，优先重构内容层级。
5. 普通说明不要放进代码块。代码块只用于：
   - Scene / 对象结构
   - 调用 / 状态流程
   - 实际代码或 API

Metadata
--------
1. Milestone、Priority、Area、Type 使用 GitHub Milestone / Labels 管理，不在正文重复。
2. 不在正文添加 `Milestone: ...` 等容易失效的 metadata。
3. Issue 依赖统一放在 `## 依赖`。

普通子 Issue 结构
----------------
## 目标
## 依赖
## 设计方案
### 按该 Issue 的实际领域拆分
## 实现步骤
## 验收标准
## 测试
## 非目标

Epic 结构
---------
Epic 不要重复复制每个子 Issue 的全部实现细节，只描述整体架构、拆分关系和完成条件。

推荐结构：
## 目标
## 总体架构
## 设计原则
## 子任务
## 实现顺序
### 第一阶段：...
### 第二阶段：...
## 完成定义
## 非目标

写作原则
--------
1. `GameState` 保存公共状态，`GameFlow` 负责流程规则——类似这样的 identifier 保留英文，说明部分使用中文。
2. 一段内容只解决一个问题，避免同一章节同时讨论职责、流程、测试和非目标。
3. Acceptance criteria 使用 `## 验收标准`；Epic 使用 `## 完成定义`。
4. 测试统一使用 `## 测试`。
5. Scope exclusion 统一使用 `## 非目标`。
6. Issue 应描述“为什么 / 如何 / 完成标准”，不要把 Labels、Milestone 等项目管理信息复制进正文。

使用说明
--------
- 默认保留下方“普通子 Issue 模板”。
- 如果创建 Epic，请删除下方普通模板，改用本注释中的 Epic 结构。
- 删除所有不适用的提示文字和空章节。
-->

## 目标

<!--
用 1–3 段说明该 Issue 完成后得到什么。
强调可交付结果，不要只写“实现 XXX”。
-->


## 依赖

<!--
列出真正影响实现顺序的 Issue。
如果没有依赖，写“无”。
示例：
- #12 `SomeSystem` 基础能力
- #18 某某流程
-->

- 

## 设计方案

<!--
根据领域使用若干 `###` 子章节。
不要为了套模板创建没有内容的章节。
常见示例：
- ### 职责边界
- ### 数据模型
- ### API
- ### 状态流程
- ### 生命周期
- ### 运行时边界
- ### 为未来联机预留
-->

### 职责与边界


### 核心流程

```text
Event / Intent
→ System A
→ System B
→ Result
```

### API / 数据模型

```gdscript
# 只放实际需要讨论的 API / 数据结构
```

## 实现步骤

1. 
2. 
3. 

## 验收标准

- [ ] 
- [ ] 
- [ ] 

## 测试

- [ ] 
- [ ] 
- [ ] 

## 非目标

- 
- 
