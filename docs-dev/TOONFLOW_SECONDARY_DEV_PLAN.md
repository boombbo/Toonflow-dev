# Toonflow 宫格分镜导演系统二开计划

> 本文来自当前代码扫描结果，只描述后续二开方案，不修改业务代码。

## 1. 当前项目事实

工作区包含两个独立仓库：

- `Toonflow-app`：Express 后端、Socket.IO 服务、Electron 桌面壳、内置前端静态资源与 `data` 运行目录。
- `Toonflow-web`：Vue 3 + TypeScript + Vite 前端源码。

启动脚本：

- `Toonflow-app/package.json`
  - `yarn dev`：`nodemon --inspect --exec tsx src/app.ts`
  - `yarn lint`：`tsc --noEmit`
  - `yarn build`：`cross-env NODE_ENV=prod tsx scripts/build.ts`
- `Toonflow-web/package.json`
  - `yarn dev`：`vite --host`
  - `yarn type-check`：`vue-tsc --build --force`
  - `yarn build`：`vue-tsc --build --force && vite build`

当前开发地址：

- 后端：`http://localhost:10588`
- 前端 Vite：`http://localhost:50188`
- 前端默认 API baseURL：`http://localhost:10588/api`

## 2. 后端路由注册方式

后端入口是 `Toonflow-app/src/app.ts`：

- 创建 Express app 与 HTTP server。
- 初始化 Socket.IO。
- 在 `NODE_ENV=dev` 时调用 `buildRoute()`。
- 注册静态目录：`/oss`、`/skills`、`/assets`、`data/web`。
- 注册全局 token 鉴权。
- 动态导入 `@/router` 并挂载所有 API 路由。

路由生成逻辑在 `Toonflow-app/src/core.ts`：

- 扫描 `src/routes/**/*.ts`。
- 根据文件路径生成 `/api${routePath}`。
- 写入 `Toonflow-app/src/router.ts`。

当前已经存在：

- `Toonflow-app/src/routes/gridDirector/health.ts`
- `GET /api/gridDirector/health`

后续新增 API 必须继续遵循文件路由风格，不要手写 Express 子路由前缀。

## 3. 前端 API 与 Socket 配置

HTTP API：

- `Toonflow-web/src/stores/setting.ts` 定义 `baseUrl`，默认 `http://localhost:10588/api`，并通过 Pinia 持久化。
- `Toonflow-web/src/utils/axios.ts` 在请求拦截器里读取 `settingStore().baseUrl`，设置 `config.baseURL` 和 `Authorization`。
- `Toonflow-web/src/services` 当前不存在，需要为 `gridDirector` 新建封装层。

Socket：

- 用户指定的 `Toonflow-web/src/utils/wsClient.ts` 当前不存在。
- 实际 Socket 客户端在：
  - `Toonflow-web/src/utils/useSocket.ts`
  - `Toonflow-web/src/utils/useChat.ts`
- Agent store 通过 `${settingStore().baseUrl}/socket/scriptAgent` 和 `${settingStore().baseUrl}/socket/productionAgent` 连接 Socket.IO。

Electron 场景：

- `Toonflow-web/src/App.vue` 会尝试调用 `toonflow://getappurl`，拿到 Electron 后端随机端口 API 地址后写回 `baseUrl`。

## 4. data/skills 与 Agent Skill 加载

`Toonflow-app/data/skills` 存在，当前包含大量 `.md` Skill 文件，例如：

- `script_agent_decision.md`
- `script_execution_skeleton.md`
- `script_execution_adaptation.md`
- `script_execution_script.md`
- `production_agent_decision.md`
- `production_execution_storyboard_table.md`
- `production_skills/**`
- `story_skills/**`
- `art_skills/**`

Skill 加载方式：

- `Toonflow-app/src/utils/getPath.ts` 统一定位 `data` 目录。
  - 非 Electron：`process.cwd()/data`
  - Electron：`app.getPath("userData")/data`
  - 内置路径穿越校验。
- `Toonflow-app/src/utils/agent/skillsTools.ts` 通过 `getPath("skills")` 读取 Skill，并做路径安全校验。
- `scriptAgent` 和 `productionAgent` 直接用 `path.join(u.getPath("skills"), "...md")` 读取主 Skill。

二开结论：

- 宫格导演 Skill 应独立放到 `Toonflow-app/data/skills/grid_director/`。
- 不复用或污染原有 `scriptAgent`、`productionAgent` 的主 Skill 文件。

## 5. task/job/status 机制复用判断

现有任务机制：

- `Toonflow-app/src/utils/taskRecord.ts` 写入 `o_tasks`。
- 状态只有中文三态：
  - `进行中`
  - `已完成`
  - `生成失败`
- 任务中心接口在 `Toonflow-app/src/routes/task/**`，支持列表、详情、分类、项目过滤。
- `Toonflow-app/src/utils/ai.ts` 在图像、视频、音频等 AI 调用里可用 `taskRecord` 记录任务。

复用判断：

- 可以复用 `o_tasks` 作为“任务中心展示/审计”的辅助记录。
- 不建议只依赖 `o_tasks` 实现宫格导演 job，因为它缺少：
  - `job_id`
  - `queued/running/succeeded/failed/cancelled`
  - 结构化结果
  - 事件日志
  - 可恢复的中间产物
- 宫格导演主状态应按规则落盘到 `Toonflow-app/data/grid-director/runs/<job_id>/`。
- 如需要接入任务中心，可在 `createJob` 时额外写 `o_tasks`，但不得替代 `job_state.json`。

## 6. 最小侵入二开方案

总体策略：

- 后端新增独立 `gridDirector` 文件夹。
- 前端新增独立 `gridDirector` 页面和 API 封装。
- 数据落盘走 `data/grid-director/runs/<job_id>/`。
- Skill 放到 `data/skills/grid_director/`。
- 不改 `package.json`。
- 不改现有 `scriptAgent` / `productionAgent` 主流程。
- 不删除或重构既有模块。

后端最小链路：

1. `health`：已具备，用于无 token 开发健康检查。
2. `createJob`：创建后端生成的 `job_id`，只在这里创建 job 目录，写入 `request.json`、`job_state.json`、`events.jsonl`。
3. 后台执行器：异步运行宫格导演流程，更新 `job_state.json` 和 `events.jsonl`。
4. `getJobStatus`：读取 `job_state.json`。
5. `getJobEvents`：读取 `events.jsonl`。
6. `getJobResult`：读取 `result.json`；未完成时返回明确状态，不报白屏错误。

前端最小链路：

1. 新增 API 封装 `Toonflow-web/src/services/gridDirector.ts`。
2. 新增页面 `Toonflow-web/src/views/gridDirector/index.vue`。
3. 在 `Toonflow-web/src/router/index.ts` 注册 `/gridDirector`。
4. 在 `Toonflow-web/src/pages/workbench/index.vue` 增加菜单入口。
5. 页面用 URL query 保存 `job_id`，刷新后恢复状态轮询。

## 7. 后续要新增的文件路径

后端：

- `Toonflow-app/src/routes/gridDirector/createJob.ts`
- `Toonflow-app/src/routes/gridDirector/getJobStatus.ts`
- `Toonflow-app/src/routes/gridDirector/getJobResult.ts`
- `Toonflow-app/src/routes/gridDirector/getJobEvents.ts`
- `Toonflow-app/src/agents/gridDirector/index.ts`
- `Toonflow-app/src/agents/gridDirector/types.ts`
- `Toonflow-app/src/agents/gridDirector/jobStore.ts`
- `Toonflow-app/src/agents/gridDirector/eventLog.ts`
- `Toonflow-app/src/agents/gridDirector/runGridDirectorJob.ts`
- `Toonflow-app/data/skills/grid_director/chief_director.md`
- `Toonflow-app/data/skills/grid_director/parent_grid.md`
- `Toonflow-app/data/skills/grid_director/child_grid.md`

前端：

- `Toonflow-web/src/services/gridDirector.ts`
- `Toonflow-web/src/views/gridDirector/index.vue`
- 修改 `Toonflow-web/src/router/index.ts`
- 修改 `Toonflow-web/src/pages/workbench/index.vue`

自动生成/运行时：

- `Toonflow-app/src/router.ts`：由 `yarn dev` 触发 `src/core.ts` 自动更新。
- `Toonflow-app/data/grid-director/runs/<job_id>/job_state.json`
- `Toonflow-app/data/grid-director/runs/<job_id>/events.jsonl`
- `Toonflow-app/data/grid-director/runs/<job_id>/request.json`
- `Toonflow-app/data/grid-director/runs/<job_id>/story_bible.json`
- `Toonflow-app/data/grid-director/runs/<job_id>/parent_grid.json`
- `Toonflow-app/data/grid-director/runs/<job_id>/approved_parent_grid.snapshot.json`
- `Toonflow-app/data/grid-director/runs/<job_id>/child_grid/`
- `Toonflow-app/data/grid-director/runs/<job_id>/result.json`
- `Toonflow-app/data/grid-director/runs/<job_id>/error.json`

## 8. API 契约草案

### `POST /api/gridDirector/createJob`

输入：

```json
{
  "projectId": 1,
  "scriptId": 1,
  "gridCount": 16,
  "requirements": "可选导演要求"
}
```

输出：

```json
{
  "job_id": "后端生成的唯一 ID"
}
```

### `GET /api/gridDirector/getJobStatus?job_id=...`

输出：

```json
{
  "job_id": "xxx",
  "status": "queued",
  "progress": 0,
  "message": "等待开始",
  "updatedAt": 0
}
```

状态枚举：

- `queued`
- `running`
- `succeeded`
- `failed`
- `cancelled`

### `GET /api/gridDirector/getJobEvents?job_id=...`

输出：

```json
{
  "job_id": "xxx",
  "events": []
}
```

### `GET /api/gridDirector/getJobResult?job_id=...`

输出：

```json
{
  "job_id": "xxx",
  "result": {}
}
```

注意：项目现有 `success()` 实际返回 `{ code, data, message }`，因此接口应复用 `success()` 包裹上述 `data`，不要自造 `{ code: 0, msg: "success" }`。

## 9. 风险点

- `wsClient.ts` 不存在：如果后续计划使用 WebSocket，需要基于现有 `useSocket.ts` / `useChat.ts`，不要引用不存在文件。
- `o_tasks` 状态粒度不足：只能辅助任务中心展示，不能承载完整 `job_id/status/result/events`。
- `data` 目录路径差异：开发环境与 Electron 环境不同，必须走 `Toonflow-app/src/utils/getPath.ts`。
- 路径穿越风险：所有 job 文件路径必须基于 `getPath(["grid-director", "runs", job_id, ...])` 或等价安全封装，不拼接用户传入路径。
- `health` 白名单只允许精确路径：不要放开整个 `/api/gridDirector`。
- `router.ts` 是生成文件：新增后端 route 后要运行或触发 `yarn dev`，保留自动更新。
- 前端 baseUrl 可被用户设置持久化：调试时可能不是默认 `http://localhost:10588/api`。
- 登录表格填入流程开发期不再使用：后续前端改造不要新增或依赖自动填登录表单流程。
- 长任务阻塞风险：`createJob` 必须快速返回，生成流程放到后台异步执行。
- 文件落盘膨胀：不要为每个小步骤创建空目录，job 目录内容限制在规则允许的文件集合内。

## 10. 推荐实施顺序

1. 后端补齐 `jobStore.ts`、`eventLog.ts`，只处理 job 目录、JSON 读写和路径安全。
2. 后端新增 `createJob/getJobStatus/getJobEvents/getJobResult` 四个 route。
3. 后端新增最小 `runGridDirectorJob.ts`，先写假数据跑通完整状态流。
4. 运行 `yarn dev` 自动更新 `src/router.ts`，执行 `yarn lint`。
5. 前端新增 `src/services/gridDirector.ts`，封装四个 API。
6. 前端新增 `src/views/gridDirector/index.vue`，覆盖 loading/error/empty/success/saving。
7. 注册前端路由和菜单入口。
8. 执行 `yarn type-check`，再做端到端手工验证。
