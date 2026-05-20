# Toonflow 项目结构理解文档

> 目的：为后续新增“宫格分镜导演系统”二开模块建立项目地图。本文只记录当前扫描到的结构与最小侵入方案，不改动业务代码。

## 1. 仓库分工

- `Toonflow-app`：Express 后端、Socket.IO 服务、Electron 桌面壳、内置前端静态资源与运行数据目录。
- `Toonflow-web`：Vue 3 + TypeScript + Vite 前端源码，构建产物会被放入后端 `data/web` 作为桌面端/后端静态站点。

## 2. 启动方式

### Toonflow-app

脚本来自 `Toonflow-app/package.json`：

- `yarn install`：安装后端/Electron 依赖。
- `yarn dev`：执行 `nodemon --inspect --exec tsx src/app.ts`，只跑后端 API 与 Socket.IO。当前源码固定端口为 `10588`，运行日志也显示 `http://localhost:10588`。
- `yarn dev:gui`：执行 `electronmon -r tsx scripts/main.ts`，启动 Electron，并在开发环境加载 `src/app.ts`。Electron 会调用 `startServe(true)` 使用随机端口，再通过 `toonflow://getappurl` 告诉内置前端 API 地址。
- `yarn dev:gui-vite`：设置 `VITE_DEV=1` 后启动 Electron，窗口加载 `http://localhost:50188`，用于联调独立 Vite 前端。
- `yarn build`：执行 `scripts/build.ts`，生成生产运行资源。
- `yarn dist:win` / `dist:mac` / `dist:linux`：先 build，再用 electron-builder 打包。

### Toonflow-web

脚本来自 `Toonflow-web/package.json`：

- `yarn install`：安装前端依赖。
- `yarn dev`：启动 Vite 开发服务，`vite.config.ts` 中端口为 `50188`。
- `yarn build`：执行 `vue-tsc --build --force && vite build`，产物输出到 `dist`。
- `yarn preview`：预览构建产物。

注意：当前 `Toonflow-web` 的 README 提到 `build:dev`、`build:prod`，但 `package.json` 中没有这两个脚本，应以后续实际脚本为准。

## 3. 前端关键位置

- 路由位置：`Toonflow-web/src/router/index.ts`。当前使用 `createWebHashHistory()`，主布局路由是 `/workbench`，子路由包括 `/project`、`/task`、`/novel`、`/scriptAgent`、`/script`、`/cornerScape`、`/production`、`/assets`、`/test`。
- 菜单入口：`Toonflow-web/src/pages/workbench/index.vue`。左侧主菜单来自 `menuList`，项目内顶部菜单来自 `rightBtnList`。
- API 封装：当前没有 `src/api` 或 `src/services` 目录，统一 Axios 实例在 `Toonflow-web/src/utils/axios.ts`。业务请求分散在 store/view 中，例如 `src/stores/scriptAgent.ts`、`src/stores/productionAgent.ts`。
- 后端地址状态：`Toonflow-web/src/stores/setting.ts`，`baseUrl` 默认是 `http://localhost:10588/api`，并持久化到本地。
- Socket 客户端：`Toonflow-web/src/utils/useSocket.ts` 与 `src/utils/useChat.ts`。Agent 页面主要通过 `useChat` 连接 `${settingStore().baseUrl}/socket/scriptAgent` 或 `${settingStore().baseUrl}/socket/productionAgent`。
- 现有 Agent 页面：`src/views/scriptAgent/index.vue`、`src/views/production/**`，对应剧本 Agent 与生产 Agent。

## 4. 后端关键位置

- app 入口：`Toonflow-app/src/app.ts`。负责创建 Express、HTTP server、Socket.IO、静态目录、中间件、鉴权、路由注册、404 与错误处理。
- Electron 入口：`Toonflow-app/scripts/main.ts`。负责初始化 Electron 窗口、复制/初始化 `data`、启动后端服务、注册 `toonflow://` 协议。
- 路由注册方式：`Toonflow-app/src/core.ts` 扫描 `src/routes/**/*.ts`，自动生成 `src/router.ts`。生成后的路由统一挂载到 `/api${routePath}`。
- 路由文件约定：每个接口文件默认导出 `express.Router()`，例如 `src/routes/project/addProject.ts` 最终注册为 `/api/project/addProject`。
- 统一响应格式：`Toonflow-app/src/lib/responseFormat.ts` 提供 `success()` 和 `error()`，现有接口多用 `res.status(200).send(success(...))`。
- 任务记录：`Toonflow-app/src/utils/taskRecord.ts` 写入 `o_tasks`，状态包括“进行中 / 已完成 / 生成失败”。已有任务中心接口在 `src/routes/task/**`。

## 5. Agent / Skill / Prompt 相关目录

- Agent 主逻辑：
  - `Toonflow-app/src/agents/scriptAgent/index.ts`
  - `Toonflow-app/src/agents/scriptAgent/tools.ts`
  - `Toonflow-app/src/agents/productionAgent/index.ts`
  - `Toonflow-app/src/agents/productionAgent/tools.ts`
- Agent Socket 路由：
  - `Toonflow-app/src/socket/routes/scriptAgent.ts`
  - `Toonflow-app/src/socket/routes/productionAgent.ts`
- Skill 文件：
  - `Toonflow-app/data/skills/*.md`
  - `Toonflow-app/data/skills/production_skills/**`
  - `Toonflow-app/data/skills/story_skills/**`
- Skill 工具与扫描：
  - `Toonflow-app/src/utils/agent/skillsTools.ts`
  - `Toonflow-web/src/utils/scanSkills.ts`
- Prompt/模型映射接口：
  - `Toonflow-app/src/routes/setting/promptManage/**`
  - `Toonflow-app/src/routes/setting/modelMap/**`
  - `Toonflow-app/src/utils/getPrompts.ts`

## 6. data 目录用途

后端通过 `Toonflow-app/src/utils/getPath.ts` 统一定位数据目录：

- 非 Electron 环境：`Toonflow-app/data`
- Electron 环境：`app.getPath("userData")/data`

当前用途：

- `data/db2.sqlite`：本地 SQLite 数据库，启动时由初始化逻辑创建业务表。
- `data/web`：内置前端静态资源，`src/app.ts` 会作为静态站点挂载。
- `data/skills`：Agent Skill Markdown 文件，既被后端读取，也可通过设置接口管理。
- `data/vendor`：模型供应商配置/实现模板。
- `data/assets`：业务素材文件目录，对外静态挂载为 `/assets`。
- `data/oss`：文件/对象资源目录，对外静态挂载为 `/oss`。
- `data/serve`：生产/Electron 打包后的后端入口资源。
- `data/models`：本地模型或运行依赖资源。
- `data/version.txt`：Electron 初始化数据时用于判断是否需要替换内置数据。

`getPath.ts` 带路径逃逸校验，新增文件读写应继续走这个入口。

## 7. WebSocket / Socket.IO 相关位置

- 后端初始化：`Toonflow-app/src/app.ts` 创建 `new Server(server, { cors: { origin: "*" } })`，并调用 `socketInit(io)`。
- 命名空间注册：`Toonflow-app/src/socket/index.ts`。当前注册：
  - `/api/socket/productionAgent`
  - `/api/socket/scriptAgent`
- Socket 鉴权：各 socket route 从 `socket.handshake.auth.token` 读取 token，并用数据库里的 `tokenKey` 做 JWT 校验。
- 前端连接：`Toonflow-web/src/utils/useChat.ts`、`src/utils/useSocket.ts`，业务 store 传入 `${baseUrl}/socket/...`。
- 消息响应工具：`Toonflow-app/src/socket/resTool.ts`，用于往前端推送文本、思考、系统消息等流式内容。

## 8. 最小侵入方案：宫格分镜导演系统

建议新增为独立模块，复用现有项目、模型、Skill、Socket 与任务表，不改现有 ScriptAgent / ProductionAgent 主流程。

后端建议：

- 新增目录 `Toonflow-app/src/routes/gridDirector/**`，提供 REST 接口，例如：
  - `createJob.ts`：创建生成任务，返回 `job_id`。
  - `getJobStatus.ts`：查询 `job_id` 的状态。
  - `getJobResult.ts`：查询生成结果。
  - `getJobEvents.ts`：查询过程事件/日志。
- 新增目录 `Toonflow-app/src/agents/gridDirector/**`，承载宫格导演编排逻辑、Prompt 拼装、结果结构化。
- 新增 Skill/Prompt 到 `Toonflow-app/data/skills/grid_director/**` 或少量顶层 `grid_director_*.md`，避免污染原有 Skill。
- 生成任务必须异步执行，接口立即返回 `job_id`，长任务用内存队列 + SQLite 状态落盘起步，后续再考虑更完整队列。
- 任务状态建议复用或扩展 `o_tasks`，必要时新增独立表；未确认数据库迁移方式前，不直接改表结构。
- 新增路由后在开发环境运行 `yarn dev` 会由 `src/core.ts` 自动更新 `src/router.ts`；提交时应包含生成后的路由文件。

前端建议：

- 新增页面目录 `Toonflow-web/src/views/gridDirector/index.vue`。
- 在 `Toonflow-web/src/router/index.ts` 注册 `/gridDirector`。
- 在 `Toonflow-web/src/pages/workbench/index.vue` 的 `rightBtnList` 增加入口，建议放在 `/production` 附近。
- 新增 API 封装文件时优先建 `Toonflow-web/src/services/gridDirector.ts`，集中定义请求参数、返回类型、错误处理；如果暂不建 `services` 目录，也至少不要在组件中裸写 `fetch`。
- 页面状态至少覆盖 `loading`、`success`、`empty`、`error`；创建任务时增加 `saving`；任务流程页面把 `job_id` 放 URL query，刷新后可恢复查询。

数据契约建议：

- 创建任务：输入 `projectId`、可选 `scriptId`、宫格数量、导演风格/约束文本；输出 `{ job_id }`。
- 状态查询：输出 `{ job_id, status, progress, message, updatedAt }`，`status` 可取 `queued | running | succeeded | failed | cancelled`。
- 结果查询：输出 `{ job_id, result }`，`result` 中保存宫格列表、镜头说明、提示词、角色/资产引用、可导出文本。
- 事件查询：输出 `{ job_id, events: [] }`，用于页面日志面板和错误定位。

实施边界：

- 不删除原有模块。
- 不大范围重构现有 Agent。
- 不硬编码 API key、token、密钥。
- 不改 `package.json`，除非后续明确需要新增依赖并先确认。
- 优先让宫格导演成为独立页面 + 独立 API + 独立 Agent 目录，和现有生产链路通过 `projectId/scriptId` 数据关联。
