# Toonflow「项目专属高定模板 / 风格锁死模板」链路扫描

> **扫描时间**：2026-05-19  
> **模式**：只读；未修改任何业务代码。

---

## 扫描范围

| 区域 | 路径 |
|------|------|
| 新建项目 UI | `Toonflow-web/src/views/project/components/projectDialog.vue` |
| 项目字段落盘 | `Toonflow-app/src/routes/project/addProject.ts`、`editProject.ts` |
| 视觉/导演手册 API | `routes/project/getVisualManual.ts`、`queryDirectorManual.ts`、`addVisualManual.ts`、`addDirectorManual.ts` 等 |
| Production Agent | `Toonflow-app/src/agents/productionAgent/index.ts` |
| Skill 工具链 | `Toonflow-app/src/utils/agent/skillsTools.ts` |
| 图像/视频 Prompt 直读 | `Toonflow-app/src/utils/getArtPrompt.ts` |
| 生成类 HTTP | `routes/production/**`、`routes/assetsGenerate/**` |
| Script Agent | `Toonflow-app/src/agents/scriptAgent/index.ts` |
| 磁盘模板 | `Toonflow-app/data/skills/art_skills/**`、`story_skills/**`、`production_skills/**` |
| 决策 Skill | `data/skills/production_agent_decision.md` |

---

## 一、项目模板入口

### 1. `projectDialog.vue` 里 artStyle 如何加载？

弹窗打开时（`watch(addProjectShow)` → `visible === true`）调用：

```ts
fetchVisualManuals(); // POST /project/getVisualManual
```

- 结果写入 `visualManualOptions`
- 网格项点击：`formState.artStyle = item.stylePath`
- **展示名**：`item.name`（来自该模板目录 `README.md` 首行）
- **绑定值**：`item.stylePath`（**目录名**）

### 2. directorManual 如何加载？

同一 `watch` 内调用：

```ts
queryDirectorManual(); // POST /project/queryDirectorManual
```

- 结果写入 `directorManualOptions`
- 点击：`formState.directorManual = item.directorManual`
- **展示名**：`item.name`（`story_skills/<dir>/README.md` 首行）
- **绑定值**：`item.directorManual`（**目录名**）

### 3–4. 列表接口

| 类型 | 接口 | 后端文件 |
|------|------|----------|
| 视觉手册列表 | `POST /api/project/getVisualManual` | `getVisualManual.ts` |
| 导演手册列表 | `POST /api/project/queryDirectorManual` | `queryDirectorManual.ts` |

两者均 **扫描 `data/skills` 下子目录**，不查 SQLite 模板表。

### 5. 手册 CRUD 路由位置

| API | 后端文件 | 作用 |
|-----|----------|------|
| `POST /api/project/addVisualManual` | `addVisualManual.ts` | 新建 `art_skills/<stylePath>/` |
| `POST /api/project/editVisualManual` | `editVisualManual.ts` | 编辑视觉手册 md |
| `POST /api/project/deleteVisualManual` | `deleteVisualManual.ts` | 删除视觉手册目录 |
| `POST /api/project/addDirectorManual` | `addDirectorManual.ts` | 新建 `story_skills/<directorManual>/` |
| `POST /api/project/editDirectorlManual` | `editDirectorlManual.ts` | 编辑导演手册（路由名拼写 `directorl`） |
| `POST /api/project/deleteDirectorManual` | `deleteDirectorManual.ts` | 删除导演手册目录 |
| `POST /api/project/getVisualManual` | `getVisualManual.ts` | 列表 + 读 md |
| `POST /api/project/queryDirectorManual` | `queryDirectorManual.ts` | 列表 + 读 md |

另有遗留 `POST /api/project/visualManual`（`visualManual.ts`，写死 `chinese_sweet_romance`），**主流程未使用**。

### 6. artStyle 的值是什么？

**结论：`o_project.artStyle` = `art_skills` 下的目录名（`stylePath`），不是 DB id，不是单个文件名。**

证据链：

- `getVisualManual` 返回 `stylePath: styleName`（`readdir` 目录名）
- `projectDialog` 选中写入 `formState.artStyle = item.stylePath`
- `addProject` 原样写入 `o_project.artStyle`
- `createArtSkills(artName)` 使用 `u.getPath(["skills", "art_skills", artName, "driector_skills"])`

示例：`3D_guofeng_cyber`、`realpeople_urban_modern`。

### 7. directorManual 的值是什么？

**结论：`o_project.directorManual` = `story_skills` 下的目录名，不是 DB id。**

- `queryDirectorManual` 返回 `directorManual: directorManual`（目录名）
- `addDirectorManual` 创建 `story_skills/<directorManual>/`

### 8. 项目创建后 production 如何读取 artStyle / directorManual？

**前端不直接读文件**；Production 页通过 Pinia：

```ts
// stores/project.ts，persist: true
const { project } = storeToRefs(projectStore());
```

**后端 Production Agent** 在 `createSubAgent` 内：

```ts
const projectInfo = await u.db("o_project").where("id", resTool.data.projectId).first();
const artSkills = await createArtSkills(projectInfo.artStyle, projectInfo.directorManual);
```

`resTool.data.projectId` 来自 Socket `handshake.auth.projectId`（前端 `productionAgent` store 传入）。

**图像/视频 HTTP 生成**（不经过 Agent）同样读 DB：

```ts
await u.db("o_project").where("id", projectId).select("artStyle", ...).first();
u.getArtPrompt(artStyle, "art_skills", "art_storyboard_video");
```

---

## 二、Agent 运行时如何使用 artStyle / directorManual

### 1–3. artName / storyName 来源与对应关系

```377:380:Toonflow-app/src/agents/productionAgent/index.ts
async function createArtSkills(artName: string, storyName: string) {
  const artWorkerPath = u.getPath(["skills", "art_skills", artName, "driector_skills"]);
  const storyWorkerPath = u.getPath(["skills", "story_skills", storyName, "driector_skills"]);
```

| 参数 | 是否等于项目字段 | 含义 |
|------|------------------|------|
| `artName` | **是** `project.artStyle` | 视觉手册目录名 |
| `storyName` | **是** `project.directorManual` | 导演手册目录名 |

若目录不存在，`scanSkills` 返回空数组，对应 Skill 列表为空（不报错，但无风格技法可激活）。

### 4–5. 调用位置

均在 `createSubAgent()`（每次决策层派发子 Agent 时）：

| 函数 | 调用处 | 用于子 Agent |
|------|--------|--------------|
| `createArtSkills` | 第 148 行 | 衍生资产、导演规划、分镜图生成（`artSkills.prompt` + `activate_skill`） |
| `useProductionSkills` | 第 297 行 | 分镜表、分镜面板（`productionSkills` + `activate_skill`） |

`useProductionSkills` **额外**扫描全局目录：

```465:472:Toonflow-app/src/agents/productionAgent/index.ts
  const productionPath = u.getPath(["skills", "production_skills"]);
  const skillList = [
    ...(await scanSkills(artWorkerPath + "/*.md")),
    ...(await scanSkills(storyWorkerPath + "/*.md")),
    ...(await scanSkills(productionPath + "/*.md")),
  ];
```

因此 `production_skills/*.md`（如 `grid_director_storyboard.md`）对 **所有项目** 可见。

### 6. 如何进入 activate_skill？

1. `scanSkills(".../driector_skills/*.md")` 收集绝对路径  
2. 每个文件 `parseFrontmatter` → 必须有 YAML frontmatter 的 **`name`**、**`description`**  
3. `buildSkillPrompt` 把 `<name>` + `<description>` 注入子 Agent 的 system/assistant 上下文  
4. 子 Agent 根据 **description 语义匹配** 调用 `activate_skill({ name })`  
5. `activate_skill` 读取全文（去掉 frontmatter）注入对话

**重要：`activate_skill` 由 LLM 决定是否调用，不是代码强制。**

### 7. 哪些执行层收到这些 Skill？

| 子 Agent 工具 | Skill 源 | activate_skill |
|---------------|----------|----------------|
| `run_sub_agent_derive_assets` | `artSkills` | 是 |
| `run_sub_agent_generate_assets` | `artSkills` | 是 |
| `run_sub_agent_director_plan` | `artSkills` | 是 |
| `run_sub_agent_storyboard_gen` | `artSkills` | 是 |
| `run_sub_agent_storyboard_table` | `productionSkills` | 是 |
| `run_sub_agent_storyboard_panel` | `productionSkills` | 是 |
| `run_sub_agent_supervision` | **无** | 否 |

决策层 `runDecisionAI` 只读 `production_agent_decision.md`，**不**挂载项目 driector_skills。

### 8. 分镜表 / 面板 / 资产生成是否继承？

| 链路 | 是否继承项目模板 | 机制 |
|------|------------------|------|
| 分镜表 / 分镜面板（Agent 写字） | **软继承** | `useProductionSkills` 扫描项目 `driector_skills` + 全局 `production_skills`；依赖 LLM 激活 |
| 衍生资产 / 导演规划（Agent） | **软继承** | `createArtSkills` |
| 批量资产图 / 分镜图（HTTP） | **硬继承（若 art_prompt 有内容）** | `getArtPrompt(artStyle, "art_skills", fileName)` 读 `art_prompt/*.md` + `prefix.md` |
| 视频 prompt（HTTP） | **硬继承** | `getArtPrompt(artStyle, "art_skills", "art_storyboard_video")` |

**双轨制：**

- **Agent 轨**：`driector_skills/*.md` + frontmatter + `activate_skill`  
- **生成 API 轨**：`art_prompt/*.md`（可无 frontmatter，`getArtPrompt` 不解析 frontmatter，整文件拼接进 prompt）

要「锁死」必须 **两条轨都写规则**，仅写 driector_skills 无法保证 HTTP 出图一致。

### ScriptAgent 补充

`scriptAgent` **不**调用 `createArtSkills`，仅在决策上下文写一行：

```ts
`目标改编影视视觉手册|画风：${projectData?.artStyle ?? "无"}`
```

剧本阶段 **无** Skill 扫描 / `activate_skill`，锁风格主要靠自然语言约束，较弱。

---

## 三、视觉手册和 Skill 的关系

### 1. `art_skills/<artName>/driector_skills/*.md` 是否就是视觉风格模板？

**是（Agent 侧技法模板）**，与 `art_prompt/*.md`（生成 API 侧 prompt 模板）并列：

```
art_skills/<artName>/
  README.md
  prefix.md
  images/
  art_prompt/           ← getArtPrompt → 出图/视频 HTTP
  driector_skills/      ← createArtSkills / useProductionSkills → activate_skill
```

### 2. 目录名 `driector_skills` 是否拼写固定？

**是，代码写死 `driector_skills`（director 拼错为 driector）。**

`addVisualManual.ts`、`getVisualManual.ts`、`productionAgent/index.ts` 均使用该字符串。**新建目录必须沿用此拼写**，否则扫描不到。

### 3. 新增 `art_skills/tony_locked_template_v1/driector_skills/style_contract.md` 会被扫描吗？

**会**，当且仅当：

1. 项目 `o_project.artStyle === "tony_locked_template_v1"`  
2. 文件带合法 frontmatter（`name` + `description`）  
3. 路径在 `driector_skills/` 下且扩展名为 `.md`

然后进入 `createArtSkills` / `useProductionSkills` 的 `<available_skills>` 列表。

### 4. frontmatter 必须字段

`skillsTools.parseFrontmatter` **强制**：

```yaml
---
name: unique_skill_id          # activate_skill 枚举值
description: 一句话说明         # 出现在 available_skills，供 LLM 选择
---
```

可选：`metaData` 等自定义键（代码不校验，仅展示在正文中）。

**缺 frontmatter 或缺字段 → 运行子 Agent 时 `parseFrontmatter` 抛错。**

### 5. description 是否影响 activate_skill？

**是。** `description` 进入决策/执行 Agent 的 `<available_skills>` XML；LLM 靠语义匹配决定是否 `activate_skill(name)`。

要写「必须先激活」类锁死，应：

- `description` 写明 **MUST / 强制 / 任何任务前首先加载**  
- 或在 `production_agent_decision.md` 增加对特定 `artStyle` 的硬规则（方案 A 可选增强）

### 6. 视觉手册 UI 创建 artStyle 是否会自动创建目录？

**会。**

`addVisualManual` → `u.getPath(["skills", "art_skills", stylePath])` → 按 `DATA_MAP` 写：

- 根目录 `README.md`、`prefix.md` 等  
- `art_prompt/*.md`  
- `driector_skills/director_*.md`  

并创建 `images/`。

### 7. 若不会（或不足）的最小改动点

| 问题 | 最小改动 |
|------|----------|
| UI 写入的 `driector_skills/*.md` **无 frontmatter** | 手改磁盘文件；或改 `addVisualManual.ts` / `editVisualManual.ts` 在 `subDir === "driector_skills"` 时自动包裹 frontmatter |
| 高定模板需固定 5 个契约文件 | **推荐仓库内预置目录** + 项目选择 `stylePath`，而非仅靠 UI 逐 tab 填写 |
| `production_skills` 全局污染 | 项目专属守卫放 **`art_skills/<template>/driector_skills/`**，勿放全局 `production_skills`（除非接受全项目可见） |

---

## 四、项目级风格锁死方案对比

| 维度 | 方案 A：复用 artStyle + directorManual + 磁盘 Skill | 方案 B：o_project 增 lockedTemplateId / JSON | 方案 C：独立 projectTemplate 表 + 管理页 |
|------|------------------------------------------------------|-----------------------------------------------|------------------------------------------|
| **改动范围** | 主要是 `data/skills/**` 文件；可选小改 `production_agent_decision.md`、手册 API frontmatter | DB 迁移 + `addProject`/`editProject` + productionAgent 读取 + 前端选择器 | 新表、新 CRUD 路由、新管理 UI、Agent 读取、迁移 |
| **风险** | 中低；LLM 可能不激活 Skill；HTTP 轨需同步 art_prompt | 中；字段与 artStyle 双源可能不一致 | 高；周期长，与现有手册体系重复 |
| **破坏现有逻辑** | **否**（不改字段语义） | 低（新增字段，旧项目 nullable） | 中（引入第二套模板源） |
| **能否锁死风格** | **软锁 + 硬锁混合**：art_prompt 硬锁出图；driector_skills + 决策文案 软锁 Agent | 可硬编码读取 JSON 注入 prompt，需开发 | 最强，但最重 |
| **适合当前阶段** | **最适合** | 适合第二阶段显式配置 | 不适合当前「尽量复用」目标 |

**结论：当前阶段推荐方案 A**，并用「预置模板目录 + art_prompt 与 driector_skills 双份契约 + 可选决策层一句强制话」补齐锁死强度。

---

## 五、推荐最小实施方案

### 1. 需要新增哪些 md 文件？（示例模板 `tony_locked_shonen_v1`）

**`data/skills/art_skills/tony_locked_shonen_v1/`**

| 路径 | 用途 |
|------|------|
| `README.md` | 列表展示名（首行） |
| `prefix.md` | 全局画风前缀（`getArtPrompt` 自动前缀） |
| `driector_skills/01_style_contract.md` | Agent：风格宪法（强制 activate） |
| `driector_skills/02_prompt_contract.md` | Agent：出图 prompt 结构 |
| `driector_skills/03_character_consistency.md` | Agent：角色一致性 |
| `driector_skills/04_negative_prompt.md` | Agent：禁止项 |
| `driector_skills/05_grid_storyboard_rules.md` | Agent：宫格/分镜表规则 |
| `art_prompt/art_character.md` 等 | HTTP：与现网字段对齐的硬 prompt |
| `art_prompt/art_storyboard_video.md` | HTTP：视频 prompt |

**可选 `data/skills/story_skills/tony_locked_narrative_v1/driector_skills/`**  
叙事/分镜表导演技法（若与视觉模板拆分）。

**不建议**在全局 `production_skills/` 放「守卫」（会对所有项目暴露）；宫格类可继续用现有 `grid_director_storyboard.md` 或复制一份进模板目录。

### 2. 是否需要新增 art_skills 目录？

**是。** 每个高定模板 = 一个 `art_skills/<stylePath>/` 目录（与现网一致）。

### 3. 是否需要新增 production_skills 守卫 Skill？

**可选，非首选。**  
项目级守卫应放在 **`art_skills/<template>/driector_skills/00_project_style_guard.md`**，仅当 `artStyle` 选中该模板时进入扫描列表。

### 4. 是否需要修改 production_agent_decision.md？

**建议小改（可选但性价比高）**：增加一节「当项目画风为锁定模板（artStyle 以 `locked_` 或维护一份名单）时，执行层子任务前必须在 prompt 中要求先 activate `style_contract`」。  
不改也能跑，锁死强度依赖 Skill description 与子 Agent 自觉。

### 5. 是否需要修改 projectDialog.vue？

**非必须。** 现有网格已能选择新目录（`getVisualManual` 自动列出）。  
可选：增加「高定模板」分组标签或 `stylePath` 前缀过滤，纯 UX。

### 6. 是否需要修改 addProject.ts？

**否**（方案 A）。继续写入 `artStyle` / `directorManual` 字符串即可。

### 7. 是否需要修改 o_project 表？

**否**（方案 A）。

### 8. 是否需要修改 productionAgent/index.ts？

**非必须。** 现有 `createArtSkills(project.artStyle, project.directorManual)` 已够用。  
若需 **强制注入** 某 Skill 正文（不依赖 LLM activate），才改此处：在 `artSkills.prompt` 末尾 append 读取 `01_style_contract.md` 全文。

### 9. 是否需要修改 ai.ts？

**否。**

### 10. 绝对不要动（除非单独立项）

| 文件/模块 | 原因 |
|-----------|------|
| `ai.ts` 核心供应商路由 | 与模板正交 |
| `scriptAgent` 主流程大改 | 当前无 Skill 链；要锁剧本需另开任务 |
| 将 `driector_skills` 批量改名为 `director_skills` | 全链路写死错拼，改名会断扫描 |
| 全局 `production_skills` 塞满项目专属守卫 | 会泄漏到所有项目 |
| `o_artStyle` 表（`routes/artStyle/*`） | 与 `o_project.artStyle` 是 **不同概念**（旧画风库） |

---

## 六、高定模板内容结构建议

```
data/skills/art_skills/tony_locked_shonen_v1/
  README.md                          # 首行：热血少年漫·锁定版
  prefix.md                          # 所有 getArtPrompt 的统一画风前缀
  images/                            # 手册封面（可选）
  driector_skills/
    01_style_contract.md             # 风格宪法：色调、线条、禁改项、与项目绑定声明
    02_prompt_contract.md            # 出图 prompt 句式、字段顺序、中英文比例
    03_character_consistency.md      # 角色脸型/服装/发型跨镜头一致
    04_negative_prompt.md            # 全局 negative：写实污染、Q版漂移等
    05_grid_storyboard_rules.md      # 16/20 宫格、景别、时长分配
  art_prompt/
    art_character.md                 # HTTP 角色生图（与契约一致）
    art_character_derivative.md
    art_scene.md
    art_prop.md
    art_storyboard_video.md          # HTTP 分镜视频 prompt
    ...                              # 与 addVisualManual DATA_MAP 对齐
```

| 文件 | 负责 |
|------|------|
| `01_style_contract` | Agent 总纲；禁止偏离画风；可要求覆盖用户临时偏好 |
| `02_prompt_contract` | 结构化 prompt；与执行层 XML 输出字段对齐 |
| `03_character_consistency` | 角色 ID、服装状态、跨镜继承 |
| `04_negative_prompt` | 禁止风格/元素列表 |
| `05_grid_storyboard_rules` | 宫格数量、父/子格、与 `grid_director_storyboard` 配合 |
| `art_prompt/*` | **绕过 LLM** 的 API 直出图/视频仍遵守同一风格 |

每个 `driector_skills/*.md` 头部示例：

```yaml
---
name: tony_style_contract
description: 【强制】本项目锁定画风宪法；任何分镜、资产、出图任务前必须首先 activate 本技能，不得跳过。
---
```

---

## 七、输出结论

### 1. 新增文档路径

`docs-dev/PROJECT_LOCKED_TEMPLATE_FLOW_MAP.md`

### 2. 扫描范围

见文首表格（前端 projectDialog、后端 project/production/assetsGenerate Agent、skills 磁盘、production_agent_decision）。

### 3. 是否修改业务代码

**没有。**

### 4. 推荐方案

**方案 A**：复用 `o_project.artStyle` / `directorManual` 作为模板键；在 `art_skills/<template>/` 预置 `driector_skills` + `art_prompt` 双轨契约；可选微调 `production_agent_decision.md` 或 `productionAgent` 注入强制正文以增强锁死。

### 5. 最小改动文件清单（实施阶段）

| 类型 | 路径 |
|------|------|
| **新增（主要）** | `Toonflow-app/data/skills/art_skills/<your_locked_template>/**` |
| **可选新增** | `Toonflow-app/data/skills/story_skills/<your_narrative_template>/**` |
| **可选改** | `Toonflow-app/data/skills/production_agent_decision.md`（锁定模板提示） |
| **可选改** | `addVisualManual.ts`（driector_skills 自动 frontmatter） |
| **不改** | `addProject.ts`、`o_project` 表、`ai.ts`、`productionAgent/index.ts`（除非要强注入） |

### 6. 不建议动的文件

- `ai.ts`
- `scriptAgent/index.ts`（剧本锁需另需求）
- 批量重命名 `driector_skills`
- 无过滤的全局 `production_skills` 项目专属守卫

### 7. 下一步开发单建议

```text
开发单 1（纯资产，无代码）：
- 在 art_skills 下新增 1 个 locked 模板目录，补全 driector_skills（5 契约）+ art_prompt（与现网字段对齐）+ README/prefix
- 用手动项目绑定 artStyle 做 production 冒烟

开发单 2（可选小改）：
- production_agent_decision.md：锁定模板必须先 activate style_contract
- 或 productionAgent：createArtSkills 后 append 读取 01_style_contract 全文

开发单 3（可选）：
- addVisualManual：保存 driector_skills 时自动加 frontmatter（name/description）
- projectDialog：高定模板分组展示

开发单 4（后续，非当前）：
- scriptAgent 接入 story_skills 扫描或只读 style_contract 摘要
- 方案 B：lockedTemplateId JSON 字段（多模板元数据）
```

---

## 附录：关键代码索引

```377:395:Toonflow-app/src/agents/productionAgent/index.ts
async function createArtSkills(artName: string, storyName: string) {
  const artWorkerPath = u.getPath(["skills", "art_skills", artName, "driector_skills"]);
  const storyWorkerPath = u.getPath(["skills", "story_skills", storyName, "driector_skills"]);
  const skillList = [...(await scanSkills(artWorkerPath + "/*.md")), ...(await scanSkills(storyWorkerPath + "/*.md"))];
  // ...
}
```

```465:488:Toonflow-app/src/agents/productionAgent/index.ts
async function useProductionSkills(artName: string, storyName: string) {
  // ... + production_skills/*.md
}
```

```11:30:Toonflow-app/src/utils/getArtPrompt.ts
export function getArtPrompt(styleName: string, source: string, fileName: string): string {
  const baseDir = getPath(["skills", source, styleName]);
  // prefix.md + 递归查找 art_prompt/*.md
}
```

---

*文档仅反映扫描时点源码与磁盘结构。*
