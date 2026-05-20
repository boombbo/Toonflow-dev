# Toonflow Skill.md 加载机制扫描图

> 扫描范围：`Toonflow-app` 与 `Toonflow-web` 中现有 Agent、Skill 管理、Skill 文件扫描与前端 Skill 管理 UI。本文只记录扫描结果，不包含业务代码改动。

## 1. Skill 文件总体情况

`Toonflow-app/data/skills` 存在，当前扫描到大量 `.md` 文件。

主要目录：

- `Toonflow-app/data/skills/*.md`
- `Toonflow-app/data/skills/production_skills/*.md`
- `Toonflow-app/data/skills/art_skills/**`
- `Toonflow-app/data/skills/story_skills/**`

现有 Skill 文件基本是 Markdown 文件，并且常见格式包含 frontmatter：

```md
---
name: xxx
description: xxx
---
```

后端解析 frontmatter 的函数在：

- `Toonflow-app/src/utils/agent/skillsTools.ts`
  - `parseFrontmatter()`

## 2. 现有 scriptAgent 如何加载 Skill

文件：

- `Toonflow-app/src/agents/scriptAgent/index.ts`

主决策 Skill：

- `script_agent_decision.md`

执行层/监督层 Skill：

- `script_execution_skeleton.md`
- `script_execution_adaptation.md`
- `script_execution_script.md`
- `script_agent_supervision.md`

加载方式：

- 通过 `path.join(u.getPath("skills"), "...md")` 读取固定文件名。
- 使用 `fs.promises.readFile()` 直接读取 Skill 内容。
- 当前 scriptAgent 的核心 Skill 文件名是硬编码的固定集合。

结论：

- 新增任意 `.md` 文件不会自动进入 scriptAgent 决策/执行流程。
- 如果要让 scriptAgent 使用“宫格分镜导演 Skill”，需要最小改动 `scriptAgent` 的决策 Skill 文案或新增一个子 Agent 调用点；但这会触碰主流程，当前路线建议优先走 productionAgent。

## 3. 现有 productionAgent 如何加载 Skill

文件：

- `Toonflow-app/src/agents/productionAgent/index.ts`

主决策 Skill：

- `production_agent_decision.md`

执行层/监督层 Skill：

- `production_execution_director_plan.md`
- `production_execution_derive_assets.md`
- `production_execution_generate_assets.md`
- `production_execution_storyboard_gen.md`
- `production_execution_storyboard_panel.md`
- `production_execution_storyboard_table.md`
- `production_agent_supervision.md`

固定读取方式：

- 和 scriptAgent 类似，核心执行 Skill 多数通过 `path.join(u.getPath("skills"), "...md")` 固定读取。

动态 Skill 扫描方式：

- `createArtSkills(artName, storyName)` 扫描：
  - `data/skills/art_skills/<artName>/driector_skills/*.md`
  - `data/skills/story_skills/<storyName>/driector_skills/*.md`
- `useProductionSkills(artName, storyName)` 扫描：
  - `data/skills/art_skills/<artName>/driector_skills/*.md`
  - `data/skills/story_skills/<storyName>/driector_skills/*.md`
  - `data/skills/production_skills/*.md`

这些扫描到的 Skill 会进入 `activate_skill` 工具。

结论：

- 如果把宫格分镜导演 Skill 放在 `data/skills/production_skills/`，更容易被 productionAgent 的 `useProductionSkills()` 自动加载为可激活 Skill。
- 如果放在新目录 `data/skills/grid_director/`，默认不会被 `useProductionSkills()` 扫描，除非最小修改 `productionAgent/index.ts` 的扫描范围。

## 4. Skill 是否都是 .md 文件

Agent 运行时扫描与 Skill 管理接口都以 `.md` 为主要单位：

- `skillsTools.scanSkills(folderPath)` 使用 fast-glob 扫描传入路径。
- `getSkillList` 使用 `fg("**/*.md")` 扫描整个 `data/skills`。
- `getSkillContent` / `saveSkillContent` 根据相对路径读取和保存 `.md` 文件。

结论：新增宫格导演 Skill 应使用 `.md` 文件。

## 5. 哪些 data/skills 子目录会被扫描

前端 Skill 管理列表：

- 接口：`POST /api/setting/skillManagement/getSkillList`
- 后端文件：`Toonflow-app/src/routes/setting/skillManagement/getSkillList.ts`
- 扫描范围：整个 `data/skills/**/*.md`

ProductionAgent 运行时：

- `art_skills/<artName>/driector_skills/*.md`
- `story_skills/<storyName>/driector_skills/*.md`
- `production_skills/*.md`

ScriptAgent 运行时：

- 不做目录扫描，主要读取固定 Skill 文件。

数据库初始化：

- `Toonflow-app/src/lib/initDB.ts` 定义 `o_skillList`、`o_skillAttribution` 初始数据。
- 当前初始化数据是内置列表，不代表运行时会自动注册所有新文件。

## 6. 新增 .md 文件是否能自动显示

能否在设置页显示：

- 可以。`getSkillList.ts` 扫描 `data/skills/**/*.md`，新增 `.md` 文件后，设置中心 Skill 管理列表理论上可显示。

能否自动被 Agent 使用：

- 不一定。
- 对 productionAgent：
  - 放在 `production_skills/*.md`：更可能被 `useProductionSkills()` 自动作为 `activate_skill` 可用项。
  - 放在 `grid_director/*.md`：默认不会被 productionAgent 运行时扫描。
- 对 scriptAgent：
  - 默认不会自动使用新增 `.md`。

## 7. 宫格分镜导演 Skill 应该放在哪个目录

基于“尽量不改现有 Agent 主流程”的目标，推荐：

- 首选目录：`Toonflow-app/data/skills/production_skills/grid_director_storyboard.md`

理由：

- `production_skills/*.md` 已被 `useProductionSkills()` 扫描。
- productionAgent 本身已经处理导演规划、分镜表、分镜面板，更贴近“宫格分镜导演”。
- 不需要新增页面。
- 不需要新增独立后端 Agent 系统。

如果必须保持规则中的 `grid_director` 独立目录：

- 目录：`Toonflow-app/data/skills/grid_director/grid_director_storyboard.md`
- 需要最小修改：
  - `Toonflow-app/src/agents/productionAgent/index.ts`
  - 在 `useProductionSkills()` 的 `skillList` 中追加扫描 `u.getPath(["skills", "grid_director"]) + "/*.md"`。

## 8. 如果不能自动显示，需要最小修改哪个文件

分两种情况：

### 设置页不显示

一般不需要修改，因为 `getSkillList.ts` 已经扫描整个 `data/skills/**/*.md`。

若不显示，优先检查：

- 文件是否以 `.md` 结尾。
- 文件是否位于 `Toonflow-app/data/skills` 下。
- 接口是否被 token 拦截。
- 前端是否刷新了设置页 Skill 管理列表。

### Agent 不能使用

最小修改文件：

- `Toonflow-app/src/agents/productionAgent/index.ts`

建议只改 `useProductionSkills()` 的扫描范围，不改 `runDecisionAI()`、不新增新 Agent、不改 Socket 协议。

## 9. 是否需要新增页面

不需要。

现有可用入口：

- 剧本 Agent 页面：
  - `Toonflow-web/src/views/scriptAgent/index.vue`
- 生产 Agent 页面：
  - `Toonflow-web/src/views/production/**`
  - 右侧聊天框：`Toonflow-web/src/views/production/components/rightChatBox/index.vue`

推荐在现有 productionAgent 页面中通过自然语言触发：

- “使用宫格分镜导演技法，帮我把这一集拆成 16 宫格分镜。”
- “激活宫格分镜导演 Skill，输出父宫格和子宫格拆分建议。”

## 10. 如果不新增页面，如何在现有 Agent 页面使用

推荐方式：

1. 新增 `production_skills/grid_director_storyboard.md`。
2. 在该 Skill 的 frontmatter 中给出明确 `name` 和 `description`。
3. 在 Skill 正文中写明：
   - 适用场景：16 宫格分镜、父宫格/子宫格、导演拆镜。
   - 输入来源：`script`、`scriptPlan`、`storyboardTable`、`assets`。
   - 输出格式：优先写入现有 `storyboardTable` 或给出可复制到分镜表的结构。
4. 用户在 productionAgent 右侧聊天框输入明确指令。
5. productionAgent 决策层调用执行层；执行层可通过 `activate_skill` 激活该 Skill。

如果决策层不主动使用：

- 最小改动 `production_agent_decision.md`，提示“宫格分镜、16 宫格、父宫格/子宫格需求时，优先调用分镜表或分镜面板执行层，并要求其激活 grid_director_storyboard”。
- 这比改 TypeScript 主流程更小。

## 11. 最小修改清单

推荐最小改法：

- 新增：`Toonflow-app/data/skills/production_skills/grid_director_storyboard.md`
- 可选修改：`Toonflow-app/data/skills/production_agent_decision.md`

如果坚持独立目录：

- 新增：`Toonflow-app/data/skills/grid_director/grid_director_storyboard.md`
- 修改：`Toonflow-app/src/agents/productionAgent/index.ts`
  - 仅在 `useProductionSkills()` 中加入 `grid_director/*.md` 扫描。

不需要：

- 不新增独立页面。
- 不新增 `createJob/getJobStatus/getJobResult`。
- 不新增 `jobStore/eventLog`。
- 不新增独立 `gridDirector` 后端 Agent 系统。
- 不修改 `package.json`。

## 12. 风险点

- `production_skills/*.md` 能被运行时扫描，但 Agent 是否主动激活仍取决于决策层提示和用户指令。
- 放到 `grid_director/` 更清晰，但需要改 `productionAgent/index.ts` 扫描范围。
- 现有 `o_skillList/o_skillAttribution` 是数据库初始化数据，不等同于运行时自动注册；设置页列表接口直接扫描文件系统，和数据库表不是同一条路径。
- `scanSkills.ts` 前端调用的是 `/setting/skillManagement/scanSkills`，但当前已读后端 `skillManagement` 目录只看到 `getSkillList/getSkillContent/saveSkillContent`，未发现 `scanSkills` 路由文件；该按钮可能依赖尚未实现或旧接口。
- Skill frontmatter 缺少 `name` 或 `description` 会被 `parseFrontmatter()` 判定为无效。
- Skill 路径必须在 `data/skills` 内，后端对读取路径做了越界校验。
- 生产 Agent 的动态 Skill 扫描依赖项目的 `artStyle` 和 `directorManual` 配置；项目配置缺失可能导致风格 Skill 加载失败。
