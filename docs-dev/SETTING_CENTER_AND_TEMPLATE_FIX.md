# 设置中心与项目模板修复说明

## 1. 模型服务 · 第三方 API

- 供应商文件：`Toonflow-app/data/vendor/third_party_api.ts`（`id: third_party_api`）
- 与 `openai`（OpenAI标准接口）分离；`openai.ts` 的 `models` 已清空，不再预置 GPT 列表
- 拉取接口：`POST /api/setting/vendorConfig/fetchRemoteModels`，body `{ vendorId: "third_party_api" }`
- 拉取成功后会 **合并写入** `o_vendorConfig.models`（按 `modelName` 去重），返回 `importedCount` / `skippedCount` / `totalCount` / `models`
- 前端：设置 → 模型服务 → 选中「第三方 API」→「拉取模型列表」→ 自动 `getVendorList` 刷新卡片
- Agent 配置：须开启「第三方 API」供应商开关（`enable=1`），下拉可见 `third_party_api:模型ID`
- 清空：`POST /api/setting/vendorConfig/clearVendorModels`（仅清空 `o_vendorConfig.models`，保留 API Key / Base URL）
- 拉取预览：`POST /api/setting/vendorConfig/fetchRemoteModels`（只读远程列表，不写 DB）
- 勾选导入：`POST /api/setting/vendorConfig/importVendorModels`（body: `{ vendorId, modelIds[] }`，单次最多 500 个）

## 2. 设置中心 · 隐藏退出登录

- `Toonflow-web/src/components/setting/index.vue` 已移除 `logoutConfig` 菜单与面板

## 3. 提示词管理

- 接口：`addPrompt` / `deletePrompt` / `copyPrompt` / `applyPrompt` / `getPrompt` / `updatePrompt`
- 前端：`components/setting/components/promptManage.vue`
- 「应用到业务」将当前条目的 `useData||data` 写入目标业务类型首条记录的 `useData`

## 4. 高定模板 locked_tony（项目模板模式）

- 视觉：`data/skills/art_skills/locked_tony_original_anime_v1/` → 运行时 `artStyle`，`getArtPrompt` 硬锁出图
- 导演：`data/skills/story_skills/locked_tony_original_anime_v1/` → 运行时 `directorManual`，叙事/分镜软约束
- **不是** DB 字段 `projectType`：`projectType` 仍为 `novel` / `script`（路由不变）
- UI：`projectDialog.vue` 左侧「项目类型」下方 **项目模板** 单选：
  - 普通项目
  - 高定模板项目 · locked_tony
- 选中高定后自动绑定并锁定 `artStyle` + `directorManual`；右侧网格只读高亮；保存前强校验恢复绑定
- 新建高定项目默认 `projectType=script`（用户仍可改回 novel）

## 验证

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/dev/start-toonflow-dev.ps1 -Mode reuse
cd Toonflow-web; yarn type-check
cd Toonflow-app; yarn lint
```
