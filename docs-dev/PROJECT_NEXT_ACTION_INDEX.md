# Toonflow 下一步开发索引

> 后续发单请直接引用编号（如 P1-2）。默认遵守 `.cursor/rules` 禁改清单。

---

## P0：只读 / 基础设施

| 编号 | 任务 | 类型 | 修改范围 | 风险 | 立即做 |
|------|------|------|----------|------|--------|
| P0-1 | 全项目自运行扫描报告 | readonly + docs | `docs-dev/PROJECT_*` | 低 | **已完成** |
| P0-2 | 启动器日常验证（reuse/restart/stop） | dev tooling | `tools/dev/*.ps1` | 低 | 按需 |
| P0-3 | cursor-self-scan 与 docs 清单同步 | docs | `docs-dev`, `.cursor/rules` | 低 | 已完成 |
| P0-4 | 工作区 git 初始化（可选） | ops | 根目录 | 低 | 可选 |

**Cursor 入口**：`执行 P0-2：用 start-toonflow-dev -Mode reuse 验证并更新 TOONFLOW_DEV_LAUNCHER.md，不改业务代码。`

---

## P1：高定模板

| 编号 | 任务 | 类型 | 修改范围 | 风险 | 立即做 |
|------|------|------|----------|------|--------|
| P1-1 | 扫描 getArtPrompt 固定文件名 | readonly | docs-dev | 低 | **已完成** |
| P1-2 | 补 locked_tony art_prompt 别名 | asset | `data/skills/.../art_prompt/` | 低 | **已完成** |
| P1-3 | production_agent_decision 轻增强 | asset/prompt | `production_skills/` | 低 | 建议 |
| P1-4 | projectDialog 高定模板快捷卡片 | frontend | `Toonflow-web/.../projectDialog.vue` | 中 | 建议 |
| P1-5 | 端到端验证：润色 + 批量出图 + 视频 prompt | 验证 | 无代码 | 低 | **建议下一步** |

**Cursor 入口**：

- `执行 P1-5：选 locked_tony 项目验证 getArtPrompt 别名与 productionAgent，只记录结果到 docs-dev，不改业务代码除非发现 bug。`
- `执行 P1-4：在 projectDialog.vue 增加 locked_tony 快捷卡片，最小 UI diff，不改 package.json。`

---

## P2：模型服务

| 编号 | 任务 | 类型 | 修改范围 | 风险 | 立即做 |
|------|------|------|----------|------|--------|
| P2-1 | 第三方 API / 本地模型 UI 入口 | frontend | `vendorConfig.vue` | 低 | **部分完成** |
| P2-2 | `/models` 自动拉取 | frontend + API | setting routes | 中 | 待定 |
| P2-3 | 本地模型 apiKey 空值兼容 | backend | `ai.ts` 周边 | **高** | 需评审 |
| P2-4 | 文档：本地 Ollama 一键配置 | docs | docs-dev | 低 | 可选 |

**Cursor 入口**：`执行 P2-2：模型服务保存后自动拉取 model 列表，先读 vendorConfig 与 openai vendor，最小改动。`

---

## P3：宫格分镜

| 编号 | 任务 | 类型 | 修改范围 | 风险 | 立即做 |
|------|------|------|----------|------|--------|
| P3-1 | productionAgent 内跑通 grid_director_storyboard | 验证 + prompt | Skill + 使用说明 | 低 | **优先** |
| P3-2 | 决策层 prompt 增强 | asset | `production_skills/` | 低 | 随后 |
| P3-3 | 独立 gridDirector API（createJob/status/events） | backend | `routes/gridDirector/` | 中 | 晚于 P3-1 |
| P3-4 | gridDirector 前端页面 + services | frontend | `views/gridDirector` | 中 | 晚于 P3-3 |

**Cursor 入口**：`执行 P3-1：在 production 页用 grid_director_storyboard 生成 16 宫格 JSON 样例，文档化步骤，不改 productionAgent/index.ts。`

---

## P4：项目模板

| 编号 | 任务 | 类型 | 修改范围 | 风险 | 立即做 |
|------|------|------|----------|------|--------|
| P4-1 | 项目模板快捷卡片 UI | frontend | project 模块 | 中 | 可选 |
| P4-2 | 默认剧本 / 集数种子 | backend + data | routes + assets | 中 | 可选 |
| P4-3 | 默认宫格参数 | config | docs / json | 低 | 可选 |
| P4-4 | lockedTemplateId 方案 B（DB 字段） | backend + DB | initDB, addProject | **高** | 暂缓 |

**Cursor 入口**：`执行 P4-1：新建项目对话框增加「高定模板」卡片，仅前端与 API 已有字段，不改 schema。`

---

## 暂时不要做

- 不要改 `Toonflow-app/src/utils/ai.ts`（除非 P2-3 明确评审通过）
- 不要改 `productionAgent/index.ts` / `scriptAgent/index.ts` 主流程
- 不要改 `initDB.ts` / `fixDB.ts` / `db2.sqlite` schema
- 不要清库、不要 `taskkill` 无脑杀进程
- 不要新增 `openai_compatible` 供应商类型（复用现有 openai）
- 不要优先做独立 gridDirector 全栈页面（先于 P3-1 Skill 跑通）
- 不要将 `driector_skills` 改名为 `director_skills`

---

## 快速发单模板

```txt
任务类型：[readonly_scan | frontend_ui | asset_only | backend_api]
引用：PROJECT_NEXT_ACTION_INDEX.md 的 [P?-?]
禁止修改：ai.ts, productionAgent/index.ts, package.json, yarn.lock, initDB.ts
验收：npm run build / 手动步骤 / docs-dev 更新
```
