# Toonflow 全项目自运行扫描报告

> 生成方式：readonly_scan + docs_only · 未改业务代码  
> 扫描根目录：`D:\ComfyUIApi\16宫格分镜_\BBBBBBBBBBBB`

---

## 1. 扫描时间

- Local: 2026-05-19 22:41+ (自检脚本时间戳)
- UTC: 2026-05-19 14:41+ UTC
- 报告写入：全项目检索任务（分模块追加）

---

## 2. 扫描模式

| 项 | 值 |
|----|-----|
| 任务类型 | `readonly_scan` + `docs_only` |
| 业务代码 | **未修改** |
| package.json / yarn.lock | **未修改** |
| DB / data/vendor | **未修改** |
| 破坏性命令 | 未执行（无 taskkill、无清库） |

自检脚本：`cursor-self-scan.ps1` **成功**；`cursor-task-report.ps1` **成功**（工作区无 `.git`）。

---

## 3. 当前仓库结构

| 路径 | 角色 | 扫描结论 |
|------|------|----------|
| `Toonflow-app/` | Express + Electron 后端、`data/` 运行目录 | present；`src/routes` 约 168 个路由文件 |
| `Toonflow-web/` | Vue3 + Vite 前端 | present；`src/views` 多业务页面 |
| `docs-dev/` | 二开地图与流程文档 | 17 个 `.md`（含本报告） |
| `tools/dev/` | 启动器 + Cursor 自检脚本 | 7 个文件（含 `toonflow-dev-lib.ps1`） |
| `.cursor/rules/` | Cursor 约束（含 gridDirector、自运行检索） | 34 项（含 skills 子目录） |
| `Toonflow-app/data/skills/` | Agent Skill `.md` 资产 | art/story/production_skills |
| `Toonflow-app/data/vendor/` | 模型供应商适配 | 只读列举，未改 |
| `config/styles/` | 高定 YAML 权威源（仓库根） | `locked_tony_original_anime_v1.yaml` |

---

## 4. 当前服务状态

来源：`docs-dev/CURSOR_SELF_SCAN_REPORT.md`（2026-05-19 22:41:49 本地）

| 服务 | 端口 | 是否监听 | Health | URL | 说明 |
|------|------|----------|--------|-----|------|
| 后端 API | 10588 | **是** | OK (200) | http://localhost:10588 | 复用现有进程，避免重复 `yarn dev` |
| gridDirector health | 10588 | 是 | OK (200) | http://localhost:10588/api/gridDirector/health | 仅 `health.ts` 已注册 |
| 前端 Vite | 50188 | **是** | OK (200) | http://localhost:50188 | 可浏览器直达 |

环境：node v22.22.0，yarn 1.22.22。

---

## 5. 本地无鉴权状态

| 层 | 开关 | 实现位置 |
|----|------|----------|
| 后端 | `TOONFLOW_LOCAL_DEV=1` | `Toonflow-app/src/utils/localMode.ts`；启动器默认注入 |
| 前端 | `VITE_TOONFLOW_LOCAL_DEV=1` | `Toonflow-web/.env.development`、`.env.dev`；`src/utils/localMode.ts` |

**边界**（见 `docs-dev/LOCAL_DEV_NO_AUTH_MODE.md`）：

- 仅跳过 Toonflow 自有 HTTP/JWT/Socket token 校验。
- **不**绕过第三方模型 `apiKey` / 供应商鉴权。

---

## 6. 启动器状态

| 文件 | 状态 |
|------|------|
| `tools/dev/start-toonflow-dev.ps1` | 已实现（Mode: ask/reuse/restart） |
| `tools/dev/stop-toonflow-dev.ps1` | 已实现（pids.json + 路径校验） |
| `tools/dev/check-toonflow-dev.ps1` | 已实现 |
| `tools/dev/toonflow-dev-lib.ps1` | 共享库 |
| `.toonflow-dev/pids.json` | 运行后可写入（复用/启动记录） |

**推荐日常启动**：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/dev/start-toonflow-dev.ps1 -Mode reuse
```

**强制重启**：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/dev/start-toonflow-dev.ps1 -Mode restart -Force
```

详见 `docs-dev/TOONFLOW_DEV_LAUNCHER.md`、`tools/dev/README.md`。

---

## 7. Cursor 自运行规则状态

### `.cursor/rules`（Toonflow 相关 `.mdc`）

| 文件 | 用途 |
|------|------|
| `00-toonflow-overview.mdc` | 双仓、端口、原则 |
| `00-toonflow-autonomous-retrieval.mdc` | 改代码前必检索 |
| `10-toonflow-safe-edit-policy.mdc` | 禁改清单 |
| `20-toonflow-known-facts.mdc` | 端口/Skill/模板事实 |
| `30-toonflow-change-report.mdc` | 任务完成报告格式 |
| `10-safe-dev-workflow.mdc` | 安全开发流程 |
| `20-grid-director-api-contract.mdc` | gridDirector API 契约 |
| `30-grid-director-output-policy.mdc` | job 落盘规则 |
| `frontend-page-lifecycle-closure.mdc` | 前端五件事 |
| `toonflow-grid-director-development.mdc` | 宫格二开总规则 |

### 自检脚本

| 脚本 | 结果 |
|------|------|
| `tools/dev/cursor-self-scan.ps1` | **成功** → `docs-dev/CURSOR_SELF_SCAN_REPORT.md` |
| `tools/dev/cursor-task-report.ps1` | **成功** → `docs-dev/CURSOR_LAST_TASK_REPORT.md` |

警告：工作区根目录无 `.git`；10588 已占用（建议 `-Mode reuse`）。

---

## 8. 后端路由系统

- **生成**：`Toonflow-app/src/core.ts` 用 `fast-glob` 扫描 `src/routes/**/*.ts`，生成 `src/router.ts`（**勿手写总路由**）。
- **挂载**：`app.ts` 将路由挂到 `/api${routePath}`。
- **新增 API**：在 `src/routes/<模块>/<动作>.ts` 新增文件 → 重新 `yarn dev` 或触发 core 生成。

### 重要 API（已存在）

| 路径 | 说明 |
|------|------|
| `/api/project/getProject` | 项目列表 |
| `/api/project/addProject` | 新建项目 → `o_project` |
| `/api/project/editProject` | 编辑项目 |
| `/api/project/delProject` | 删除项目 |
| `/api/general/getSingleProject` | 单项目详情 |
| `/api/setting/vendorConfig/*` | 模型供应商 CRUD / 测试 |
| `/api/setting/skillManagement/*` | Skill 列表与内容 |
| `/api/gridDirector/health` | 宫格导演健康检查（**仅此**） |

**gridDirector**：`src/routes/gridDirector/` 目前仅有 `health.ts`；无 `createJob` / `getJobStatus` 等独立任务 API。

---

## 9. 前端页面与路由

入口：`Toonflow-web/src/router/index.ts` → 布局 `pages/workbench/index.vue`。

| 页面 | 路由 | 主要文件 | 作用 | Store/API |
|------|------|----------|------|-----------|
| 项目 | `/project` | `views/project/index.vue`, `projectDialog.vue` | 新建/编辑项目、artStyle/directorManual | project store → `/api/project/*` |
| 剧本 | `/script` | `views/script/` | 剧本与集数 | scriptId |
| 剧本 Agent | `/scriptAgent` | `views/scriptAgent/index.vue` | scriptAgent 对话 | Socket/HTTP |
| 制作 | `/production` | `views/production/index.vue` | 分镜/资产/工作台 | productionAgent、scriptId、episodesId |
| 资产 | `/assets` | `views/assets/` | 资产生成与润色 | getArtPrompt 轨 |
| 设置 | workbench 内嵌 | `components/setting/**` | 模型服务、Skill、DB | vendorConfig API |
| 任务 | `/task` | `views/task/` | 任务列表 | o_tasks |

**无** `gridDirector` 独立前端路由（`rg gridDirector` 在 Toonflow-web 无匹配）。

---

## 10. 项目创建链路

```
用户 → projectDialog.vue
  → POST /api/project/addProject
  → o_project（artStyle, directorManual, type, intro…）
  → GET /api/project/getProject
  → Pinia project persist
  → /script、/production 使用 project.id / scriptId / episodesId
```

要点：

- `artStyle` = `art_skills` **目录名**（如 `locked_tony_original_anime_v1`）。
- `directorManual` = `story_skills` **目录名**。
- Production 依赖 **projectId + scriptId + episodesId**（见 `PROJECT_CREATE_FLOW_MAP.md`）。

---

## 11. 模型服务链路

```
设置 → vendorConfig.vue
  → o_vendorConfig（baseUrl, apiKey, modelName…）
  → data/vendor/openai.ts 等
  → o_agentDeploy.modelName = vendorId:modelName
  → u.Ai.Text / 图像视频接口
  → productionAgent / scriptAgent
```

- 现有 **openai** 供应商可作 OpenAI-Compatible（`USE_EXISTING_OPENAI_COMPATIBLE_PROVIDER.md`）。
- 本地模型：`openai` + `http://localhost:11434/v1` 等 + **非空占位 apiKey**。
- 前端已加「第三方 API / 本地模型」轻 UI 卡片（`MODEL_SERVICE_UI_PRESETS.md`）。

---

## 12. Skill 加载链路

| 来源 | 路径 | 消费者 |
|------|------|--------|
| 设置页扫描 | `data/skills/**/*.md`（frontmatter） | skillManagement API |
| 制作 Agent | `production_skills/*.md` | productionAgent `activate_skill` |
| 画风 | `art_skills/<artName>/driector_skills/*.md` | productionAgent 动态扫描 |
| 叙事 | `story_skills/<storyName>/driector_skills/*.md` | productionAgent |
| 剧本 Agent | 固定路径 | scriptAgent（勿与 production 混用） |

**固定错拼**：目录名必须为 `driector_skills`（代码写死），**不要**改成 `director_skills`。

工具函数：`getSkillList` / `getSkillContent` / `saveSkillContent`（设置 API）；`skillsTools.ts` 内 `activate_skill`。

---

## 13. locked_tony_original_anime_v1 高定模板状态

目录：`Toonflow-app/data/skills/art_skills/locked_tony_original_anime_v1/`（**19 文件**）

| 文件/目录 | 是否存在 | 作用 | 风险 |
|-----------|----------|------|------|
| `README.md` | 是 | 列表展示名、用法 | 低 |
| `prefix.md` | 是 | getArtPrompt 自动前缀 | 低 |
| `art_prompt/image_prompt.md` | 是 | 图像契约 | 低 |
| `art_prompt/video_prompt.md` | 是 | 视频契约 | 低 |
| `art_prompt/negative_prompt.md` | 是 | 全局负面词 | 低 |
| `art_prompt/art_character.md` 等 7 个别名 | **是** | HTTP 硬锁 getArtPrompt | 低（已补齐） |
| `driector_skills/00~06` | 是 | Agent 软锁宪法 | 中（依赖 LLM 激活 Skill） |

**当前锁级**：Agent 软锁（driector_skills）+ HTTP 硬锁（prefix + art_* 别名）+ 契约文档。  
**未做**：DB `lockedTemplateId`、projectDialog 快捷卡片（见 `PROJECT_NEXT_ACTION_INDEX.md` P4）。

---

## 14. gridDirector / 宫格分镜当前状态

| 能力 | 状态 |
|------|------|
| `GET /api/gridDirector/health` | **已有** |
| `createJob` / `getJobStatus` / `getJobResult` / `getJobEvents` | **未实现**（路由目录仅 health） |
| 前端 `views/gridDirector` | **无** |
| `Toonflow-web/src/services/gridDirector.ts` | **无** |

**推荐当前用法**：通过 `production_skills/grid_director_storyboard.md` + **productionAgent** 对话激活 Skill，在分镜表/面板产出 JSON（`05_storyboard_grid_contract.md` 约束画风）。

独立 gridDirector 全栈（job 落盘 `.toonflow-dev` 或 `data/grid-director/runs`）排在 P3，晚于 Skill 跑通。

---

## 15. 数据库与高风险表

扫描未打开 `db2.sqlite`；表名来自 `initDB.ts` / 文档：

| 表 | 用途 |
|----|------|
| `o_project` | 项目；`artStyle`、`directorManual` |
| `o_script` | 剧本/集 |
| `o_vendorConfig` | 模型供应商 |
| `o_agentDeploy` | Agent 绑定模型 `vendorId:modelName` |
| `o_prompt` / `o_modelPrompt` | Prompt 管理 |
| `o_skillList` / `o_skillAttribution` | Skill 元数据 |
| `memories` | 记忆配置 |
| `o_tasks` | 任务 |

**本次**：未改 schema、未清库。

---

## 16. 高风险文件清单

| 文件 | 原因 |
|------|------|
| `package.json` / `yarn.lock` | 依赖与锁文件 |
| `Toonflow-app/src/utils/ai.ts` | 全模型入口 |
| `productionAgent/index.ts` | 制作主流程 |
| `scriptAgent/index.ts` | 剧本主流程 |
| `initDB.ts` / `fixDB.ts` | Schema |
| `data/db2.sqlite` | 运行库 |
| `data/vendor/**` | 供应商适配 |
| `Toonflow-web/src/router/index.ts` | 总路由 |
| `pages/workbench/index.vue` | 壳布局 |

---

## 17. 当前已完成能力

- 本地无鉴权（`TOONFLOW_LOCAL_DEV` / `VITE_TOONFLOW_LOCAL_DEV`）
- 一键启动器（start/stop/check + `-Mode reuse`）
- Cursor 自检（cursor-self-scan / cursor-task-report + 4 条 toonflow rules）
- OpenAI-Compatible 复用现有 openai 供应商（文档 + 设置 UI 轻量入口）
- `grid_director_storyboard` production Skill
- `locked_tony_original_anime_v1` 高定模板（prefix + art_prompt 别名 + driector_skills 00–06）
- 模型服务「第三方 API / 本地模型」预设卡片（vendorConfig.vue）

---

## 18. 当前待验证能力

- productionAgent 普通对话与工具调用
- `grid_director_storyboard` 激活后 JSON 落分镜表
- `locked_tony` 相关 Skill 激活与自检清单
- 资产润色/批量出图是否读到 `art_*` 别名 + prefix
- 本地模型 / 第三方 baseUrl 端到端出图（需有效 apiKey）

---

## 19. 当前风险

| 风险 | 说明 |
|------|------|
| better-sqlite3 / Node ABI | 换 Node 版本可能 `ERR_DLOPEN_FAILED` |
| 非 openai 供应商 | 部分能力未全链路支持 |
| Skill 非强制 | 由 LLM 决定是否 `activate_skill` |
| 全量 type-check | 存在 `generate copy.vue` 等历史坏文件 |
| 10588 占用 | 重复启动 EADDRINUSE；用启动器 reuse |
| 无 git | 工作区根无 `.git`，变更需人工备份 |

---

## 20. 推荐下一步（≤5）

1. **P1 验证**：选 `locked_tony_original_anime_v1` 项目，跑 productionAgent + 资产润色，确认 getArtPrompt 别名生效。
2. **P3-1**：production 内跑通 `grid_director_storyboard` 并记录样例 JSON。
3. **P2**：模型服务 `/models` 拉取与 apiKey 空值策略（若仍阻塞本地模型）。
4. **P4-2**：projectDialog 高定模板快捷卡片（纯前端，可选 DB 方案 B 后置）。
5. **文档**：以 `PROJECT_NEXT_ACTION_INDEX.md` 为后续发单入口，避免重复全库扫描。

---

## 附录 A：必读 docs-dev 文档状态

| 文档 | 状态 |
|------|------|
| TOONFLOW_PROJECT_MAP.md | OK |
| TOONFLOW_SECONDARY_DEV_PLAN.md | OK |
| LOCAL_DEV_NO_AUTH_MODE.md | OK |
| AUTH_MEMBERSHIP_MAP.md | OK |
| MODEL_PROVIDER_MAP.md | OK |
| USE_EXISTING_OPENAI_COMPATIBLE_PROVIDER.md | OK |
| MODEL_SERVICE_PANEL_DEEP_MAP.md | OK |
| SETTINGS_MODULES_DEEP_MAP.md | OK |
| SKILL_MD_LOADING_MAP.md | OK |
| PROJECT_CREATE_FLOW_MAP.md | OK |
| PROJECT_LOCKED_TEMPLATE_FLOW_MAP.md | OK |
| LOCKED_TONY_TEMPLATE_IMPLEMENTATION.md | OK |
| TOONFLOW_DEV_LAUNCHER.md | OK |
| CURSOR_AUTONOMOUS_RETRIEVAL.md | OK |
| CURSOR_SELF_SCAN_REPORT.md | OK（本次更新） |
| CURSOR_LAST_TASK_REPORT.md | OK（本次更新） |
| MODEL_SERVICE_UI_PRESETS.md | OK（额外） |

## 附录 B：关键词扫描摘要

| 关键词族 | 结论 |
|----------|------|
| addProject / artStyle | `routes/project/addProject.ts` + `projectDialog.vue` |
| getArtPrompt | `utils/getArtPrompt.ts` + 6 处 routes 调用 |
| driector_skills | productionAgent 动态路径，错拼固定 |
| locked_tony_original_anime_v1 | 资产目录 19 文件 |
| gridDirector | 仅 health API |
| TOONFLOW_LOCAL_DEV | 前后端 localMode + 启动器 |

---

*全报告生成完毕 · readonly_scan + docs_only*
