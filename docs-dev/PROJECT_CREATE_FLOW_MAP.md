# Toonflow「新建项目」链路深度扫描

> **扫描时间**：2026-05-19  
> **模式**：只读；未修改 `Toonflow-app` / `Toonflow-web` 任何业务代码。

---

## 扫描范围

| 区域 | 路径 |
|------|------|
| 前端入口 | `Toonflow-web/src/views/project/index.vue`、`components/projectDialog.vue`、（遗留）`components/addProject.vue` |
| 前端路由 / 工作台 | `Toonflow-web/src/router/index.ts`、`src/pages/workbench/index.vue` |
| 前端状态 / 请求 | `Toonflow-web/src/stores/project.ts`、`src/utils/axios.ts`、`src/stores/setting.ts` |
| 前端下游 | `views/script*`、`views/production*`、`views/assets*`、`views/novel*`、`stores/scriptAgent.ts`、`stores/productionAgent.ts`、`utils/useChat.ts` |
| 后端路由 | `Toonflow-app/src/routes/project/**`、`src/routes/general/updateProject.ts`、`getSingleProject.ts` |
| 路由注册 | `Toonflow-app/src/core.ts` → `src/router.ts` |
| 响应格式 | `Toonflow-app/src/lib/responseFormat.ts` |
| 数据库 | `Toonflow-app/src/lib/initDB.ts`（`o_project` 及关联表） |
| Agent Socket | `Toonflow-app/src/socket/routes/scriptAgent.ts`、`productionAgent.ts` |

---

## 一、前端入口

### 1. 「我的项目」页面对应哪个 Vue 文件？

- **主页面**：`Toonflow-web/src/views/project/index.vue`
- **路由**：`/project`（`Hash` 模式，完整 URL 形如 `http://localhost:50188/#/project`）
- **父布局**：`Toonflow-web/src/pages/workbench/index.vue`（左侧菜单第一项「我的项目」→ `path: "/project"`）

### 2. 「+ 新建项目」按钮在哪里？

- **文件**：`Toonflow-web/src/views/project/index.vue`
- **位置**：模板 `.header` 内 `t-button.addBtn`（约第 8–16 行）
- **文案**：`$t("workbench.project.newProject")`（中文一般为「新建项目」）
- **点击逻辑**：
  ```ts
  editProjectData = null;
  dialogShow = true;
  ```

### 3. 点击后打开的弹窗 / 组件？

- **当前主链路**：`Toonflow-web/src/views/project/components/projectDialog.vue`
- **绑定**：`<projectDialog v-model="dialogShow" :projectData="editProjectData" @add="addProjectFn" @edit="editProjectFn" />`
- **遗留组件**（未被 `index.vue` 引用）：`components/addProject.vue`（旧版简化弹窗，字段不全，若单独使用会因后端 Zod 校验缺少字段而失败）

### 4. 表单字段有哪些？

`projectDialog.vue` 中 `formState` / `ProjectFormData`：

| 字段 | UI 控件 | 说明 |
|------|---------|------|
| `projectType` | `t-select` | `novel`（基于小说原文）/ `script`（基于剧本） |
| `name` | `t-input` | 项目名称 |
| `type` | `t-input` | 小说类型（如玄幻、科幻） |
| `imageModel` | `modelSelect` | 图像模型，`vendorId:modelName` 形式 |
| `imageQuality` | `t-select` | `1K` / `2K` / `4K` |
| `videoModel` | `modelSelect` | 视频模型 |
| `mode` | `t-select` | 视频模式（依赖所选 videoModel 的 mode 列表） |
| `videoRatio` | `t-select` | `16:9` / `9:16` |
| `intro` | `t-textarea` | 项目简介 |
| `artStyle` | 视觉手册网格选择 | 值为 `stylePath`（技能目录名） |
| `directorManual` | 导演手册网格选择 | 值为 `directorManual` 路径键 |

弹窗内还可 **独立** 管理视觉手册 / 导演手册（`addVisualManual`、`addDirectorManual` 等），与「新建项目」提交无耦合，仅在选择画风 / 导演风格时使用已有手册列表。

### 5. 表单默认值（`DEFAULT_FORM`）

| 字段 | 默认值 |
|------|--------|
| `projectType` | `"novel"` |
| `name` / `intro` / `type` / `artStyle` / `directorManual` | `""` |
| `videoRatio` | `"16:9"` |
| `imageModel` / `videoModel` / `imageQuality` / `mode` | `""` |

### 6. 是否有表单校验？

**有**，在 `projectDialog.vue` → `handleOk()` 内前端校验（`window.$message.warning`），全部通过才 `emit`：

- `name`、`type`、`imageModel`、`videoModel`、`artStyle`、`directorManual`、`videoRatio`、`intro`、`imageQuality`、`mode` 均不可为空

后端另有 Zod `validateFields`（见第三节）。

### 7. 点击确认调用哪个函数？

1. `projectDialog.vue` → `handleOk()` → `emit("add", ProjectFormData)`
2. `index.vue` → `addProjectFn(data)` → `axios.post("/project/addProject", data)`

编辑模式走 `emit("edit")` → `editProjectFn` → `POST /project/editProject`。

### 8. Axios 如何调用？

```ts
// index.vue
axios.post("/project/addProject", data)
```

- 使用 `@/utils/axios` 默认实例
- 相对路径，由拦截器拼接 `baseURL`

### 9. 请求前 loading / saving？

- **弹窗确认按钮**：无 `loading` / `saving` 绑定；`handleOk` 校验通过后 **立即** `resetForm()` 并关闭弹窗（`addProjectShow = false`），**不等待** HTTP 完成
- **父组件 `addProjectFn`**：无显式 loading；仅 success / error toast

### 10. 成功后如何关闭弹窗？

- 在 `handleOk` 里 **同步关闭**（emit 之后即 `addProjectShow.value = false`），不依赖 API 回调

### 11. 成功后如何刷新项目列表？

```ts
// index.vue addProjectFn
.then(() => {
  window.$message.success($t("workbench.project.msg.addSuccess"));
  getAllProject(); // POST /project/getProject → allProject.value = data
})
```

`onMounted` 时也会 `getAllProject()`。

### 12. 成功后是否自动跳转？

**否。** 新建成功后停留在「我的项目」列表页，**不**自动进入详情 / 剧本 / 制作。

进入下游需用户 **点击项目卡片** → `openProject(projectId)`：

- 校验 `imageModel` / `videoModel` 及模型可用性
- `project.value = item`（写入 Pinia `stores/project.ts`，`persist: true`）
- `projectType === "novel"` → `router.push("/novel")`
- `projectType === "script"` → `router.push("/script")`

### 13. 失败后如何展示错误？

```ts
.catch((e) => {
  window.$message.error(e.message ?? $t("workbench.project.msg.addFailed"));
});
```

Axios 错误拦截器返回 `error?.response?.data`，通常含 `message` 字段。

### 14–15. 项目列表如何加载 / 接口在哪调用？

- **Store**：`stores/project.ts` → `allProject`（`persist: true`）
- **加载函数**：`index.vue` → `getAllProject()` → `POST /project/getProject`
- **时机**：`onMounted`；增删改成功后再次调用

### 项目卡片展示字段

`name`、`projectType`（标签）、`artStyle`（标签）、`intro`（摘要）、`createTime`（格式化时间）

---

## 二、HTTP 传输协议

### 1–2. 方法与路径

| 操作 | 方法 | 完整路径（默认 baseURL 下） |
|------|------|---------------------------|
| 新建项目 | **POST** | `/api/project/addProject` |
| 项目列表 | **POST** | `/api/project/getProject` |

前端写法：`axios.post("/project/addProject", body)`（拦截器已加 `/api` 前缀的 baseURL）。

### 3–4. 传参与 Content-Type

- **传参位置**：`req.body`（JSON）
- **Content-Type**：`application/json`（Axios 默认）

**`addProject` 请求 body 字段**（与 `projectDialog` emit 一致）：

```json
{
  "projectType": "novel",
  "name": "项目名称",
  "intro": "简介",
  "type": "玄幻",
  "artStyle": "某视觉手册 stylePath",
  "directorManual": "某导演手册键",
  "videoRatio": "16:9",
  "imageModel": "openai:gpt-image-xxx",
  "videoModel": "openai:some-video-model",
  "imageQuality": "2K",
  "mode": "text"
}
```

### 5–6. baseURL

- **定义**：`Toonflow-web/src/stores/setting.ts` → `baseUrl = ref("http://localhost:10588/api")`
- **使用**：`axios.ts` 请求拦截器 `config.baseURL = baseUrl.value`
- **持久化**：Pinia `persist.pick: ["baseUrl", ...]`

### 7. Authorization

```ts
// axios.ts
const token = localStorage.getItem("token");
if (token) {
  config.headers.Authorization = token;
}
```

- **本地无鉴权模式**（`VITE_TOONFLOW_LOCAL_DEV === "1"`）：路由守卫放行，但 **若 localStorage 仍有 token 仍会带上**
- 无 token 时 **不** 发送 Authorization 头

### 8–9. 统一实例与响应结构

- **统一实例**：`@/utils/axios` 单例
- **响应拦截器**：`return response.data`，故 `.then(({ data }) => ...)` 中的 `data` 实为 **业务载荷里的 `data` 字段**

**后端统一结构**（`responseFormat.ts`）：

```ts
// 成功
{ code: 200, data: T | null, message: "成功" | string }
// 失败（error 函数）
{ code: 400, data: T | null, message: string }
```

校验失败（middleware）：HTTP 400，`{ message: "参数错误", errors: string[] }`（**非** success/error 包装）。

### 10–12. 成功 / 失败判断与取数

| 场景 | 前端行为 |
|------|----------|
| HTTP 2xx + `addProject` | `.then()` 即视为成功；**未**检查 `code === 200` |
| HTTP 4xx / 网络错误 | `.catch()`，`e.message` 展示 |
| `getProject` 列表 | `({ data }) => { allProject.value = data }` → `data` 为项目数组 |

`addProject` 成功响应示例：

```json
{
  "code": 200,
  "data": { "message": "新增项目成功" },
  "message": "成功"
}
```

前端 **不读取** 新建返回的 `id`；列表靠再次 `getProject` 拉全量。

### 13–14. services 封装

- **无** `src/services/project.ts` 一类集中封装
- 项目相关请求分散在：
  - `views/project/index.vue`
  - `views/project/components/projectDialog.vue`
  - 各业务页通过 `projectStore().project?.id` 拼 body

---

## 三、后端接口

### 1–2. 新建项目路由文件与 API 路径

| 项 | 值 |
|----|-----|
| 文件 | `Toonflow-app/src/routes/project/addProject.ts` |
| 注册 | `app.use("/api/project/addProject", route93)`（`router.ts` 自动生成） |
| 路由模块 | `export default router.post("/", ...)` |

`core.ts` 规则：`src/routes/project/addProject.ts` → `/api/project/addProject`。

### 3–4. 导出方式与参数来源

- `express.Router()` + `router.post("/", handler)`
- 参数来自 **`req.body`**
- 中间件：`validateFields({ ... })`（Zod，默认 `body`）

### 5–8. 字段、必填、校验

**必填**（Zod，全部 `z.string()`）：

`projectType`, `name`, `intro`, `type`, `artStyle`, `directorManual`, `videoRatio`, `imageModel`, `videoModel`, `imageQuality`, `mode`

- **无** 重复项目名校验
- **无** 显式鉴权中间件（与多数 setting 路由一致，依赖部署层 / 登录体系）

### 9–12. 数据库写入

```ts
await u.db("o_project").insert({
  id: Date.now(),        // 手动时间戳作主键，非自增
  projectType, name, intro, type, artStyle, videoRatio,
  directorManual, userId: 1,   // 写死 userId=1
  imageModel, videoModel, createTime: Date.now(),
  imageQuality, mode,
});
```

- **表**：`o_project`（SQLite，Knex）
- **无事务**
- **不** 同步创建默认剧本 / 集数 / 分镜
- **不** 创建 `data/projects/<id>/` 目录（删除时才会尝试删 OSS 目录 `${id}/`）

### 13–17. 文件、响应、鉴权

| 问题 | 结论 |
|------|------|
| 写 data 目录？ | 否（仅 DB） |
| 使用 getPath？ | 否 |
| 成功响应 | `success({ message: "新增项目成功" })` → HTTP 200 |
| 失败响应 | 校验失败 400 JSON；业务层较少用 `error()` |
| 鉴权 | 路由内无 JWT 校验；Socket Agent 有 token 校验 |

---

## 四、数据库表与数据结构

### 1–2. 项目表 `o_project` 字段（`initDB.ts`）

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | integer PK | **非自增**；新建用 `Date.now()` |
| `projectType` | string | `novel` / `script` |
| `imageModel` | string | 如 `openai:xxx` |
| `imageQuality` | string | `1K`/`2K`/`4K` |
| `videoModel` | string | |
| `mode` | string | 视频生成模式 key |
| `name` | text | |
| `intro` | text | |
| `type` | text | 小说类型文案 |
| `artStyle` | text | 视觉手册 `stylePath` |
| `directorManual` | text | 导演手册键 |
| `videoRatio` | text | |
| `createTime` | integer | 毫秒时间戳 |
| `userId` | integer | 新建固定 `1` |

**无** `updatedAt`、**无** 项目状态字段、**无** 独立 JSON 配置列。

### 7–10. 关联表（新建时 **不** 写入）

| 关联 | 表 | 关联键 |
|------|-----|--------|
| 小说原文 | `o_novel` | `projectId` |
| 剧本 | `o_script` | `projectId` |
| 资产 | `o_assets` | `projectId` |
| 分镜 / 视频等 | `o_storyboard`, `o_video`, `o_videoTrack`, ... | `projectId` |
| Agent 工作区 | `o_agentWorkData` | `projectId` |
| 记忆 | `memories` | `isolationKey` 形如 `{projectId}:scriptAgent` |

**删除项目**（`delProject.ts`）：级联删上述多表 + `u.oss.deleteDirectory(\`${id}/\`)` + `memories` 按 `isolationKey` 模糊删。

### 11–12. 列表 / 详情

- **列表**：`getProject` → `select("*")` 全表，**无联表**
- **单项目**：`POST /api/general/getSingleProject`（`routes/general/getSingleProject.ts`），body `{ id: number }`
  - 注意：`stores/index.ts` 误写为 `POST /project/getSingleProject`（**路径错误**），仅 `about.vue` 引用；主流程用 `stores/project.ts`

### 14–15. 宫格导演挂接建议

- 使用 **`o_project.id`**（number，前端常作 string 传递）
- 剧本级数据用 **`o_script.id`** 作为 `scriptId` / `episodesId`（production 中选集下拉）

---

## 五、项目列表与项目详情使用方式

### 1–3. 列表请求与卡片

见第一节；卡片字段：`name`, `projectType`, `artStyle`, `intro`, `createTime`。

### 4–6. 点击卡片与 projectId 传递

- **跳转**：`openProject` → `/novel` 或 `/script`（**非** production）
- **projectId 载体**：**Pinia `stores/project.ts` → `project`（persist: true）**
- **路由 query/params**：**无** `projectId`；Hash 路由仅为 `/novel`、`/script` 等

### 7–10. 下游页面读取 projectId

统一模式：

```ts
import projectStore from "@/stores/project";
const { project } = storeToRefs(projectStore());
// API: projectId: project.value?.id
```

| 页面 | 用法 |
|------|------|
| `script/index.vue` | `getScrptApi`、`addScript` 等带 `projectId` |
| `scriptAgent/index.vue` | HTTP + Socket 均依赖 `project.value?.id` |
| `production/index.vue` | `getScrptApi` 拉剧本列表 → `episodesId`；各节点 API 带 `projectId` |
| `assets/index.vue` | 资产 CRUD 带 `projectId` |
| `novel/index.vue` | 小说数据带 `projectId` |

### 11–13. 刷新后能否恢复？

- **可以**：`project` 在 Pinia **persist** 中；刷新后 `project.id` 仍在
- **无** URL 级 projectId；若用户清缓存或从未选项目就 deep-link 到 `/production`，`project` 可能为 `null`，接口 `projectId` 为空

### 14. 新功能如何拿 projectId？

```ts
const { project } = storeToRefs(projectStore());
if (!project.value?.id) {
  // 提示先选项目或跳 /project
}
const projectId = project.value.id;
```

---

## 六、新建项目与 ScriptAgent / ProductionAgent

### 1–2. 是否需要 projectId？

**是。** 两者都依赖当前选中项目。

### 3–4. Socket 连接参数（`useChat.ts` + stores）

**ScriptAgent**（`stores/scriptAgent.ts`）：

```ts
url: `${baseUrl}/socket/scriptAgent`   // 例：http://localhost:10588/api/socket/scriptAgent
auth: {
  token: localStorage.getItem("token"),
  isolationKey: `${projectId}:scriptAgent`,
  projectId: projectId,
}
```

**ProductionAgent**（`stores/productionAgent.ts`）：

```ts
url: `${baseUrl}/socket/productionAgent`
auth: {
  token: localStorage.getItem("token"),
  isolationKey: `${projectId}:productionAgent:${episodesId}`,
  projectId: projectId,
  scriptId: episodesId,  // 当前选中剧本/集 id
}
```

后端（`socket/routes/scriptAgent.ts` / `productionAgent.ts`）：

- 校验 `handshake.auth.token`（非 localDev 模式）
- 必需 `isolationKey`；`projectId` 传入 `ResTool`
- Production 支持 `updateContext` 事件更新 `projectId` / `scriptId`

### 5. scriptId / episodeId 来源

- **非新建项目时创建**：用户在「剧本管理」`addScript` 等接口创建 `o_script`
- **Production**：`getScriptData()` → `POST /script/getScrptApi` → 下拉 `episodesId` = 剧本 `id`

### 6–8. 新建后是否必须先有剧本？Production 无剧本时？

- **新建项目不创建剧本**；进入 production 前需有 `o_script` 记录
- `production/index.vue`：`episodesOptions` 为空则 `episodesId` 无值，流程图节点数据为空，Agent 的 `scriptId` 可能 `undefined`

### 9–10. Agent 结果绑定与宫格 Skill 取数

- 计划数据：`o_agentWorkData`（`getPlanData` / `setPlanData`，key `projectId` + `agentType`）
- 记忆：`memories.isolationKey` = `{projectId}:scriptAgent` 等
- **宫格分镜 Skill**：应从 **`projectStore().project.id`** + 当前 **`episodesId`（scriptId）** 取上下文；剧本正文走 `o_script` / novel 接口

---

## 七、文件与目录副作用

| 问题 | 结论 |
|------|------|
| 新建项目创建文件夹？ | **否** |
| 写 data/assets？ | **否** |
| 写 data/oss？ | **否**（删除项目时可能删 `${id}/`） |
| 项目封面？ | 弹窗选手册封面图，存的是 **手册** 的 base64/OSS，不是 `o_project` 封面字段 |
| 视觉/导演手册 | 写 `data/skills/art_skills/`、`data/skills/story_skills/`（全局手册，非 per-project） |
| 删除项目删文件？ | **是**，OSS `${projectId}/` + DB 级联 |
| 新功能在项目下写目录？ | 可参考 `delProject` 的 `${id}/` 约定；宫格产物更建议 **DB + 统一 output 策略**（与 gridDirector 规则一致时用 `data/.../runs`） |

---

## 八、项目相关 API 清单

| API | 方法 | 前端调用位置 | 后端文件 | 请求参数（body） | 响应 data | 作用 |
|-----|------|--------------|----------|------------------|-----------|------|
| `/project/getProject` | POST | `project/index.vue` | `getProject.ts` | 无 | `o_project[]` | 项目列表 |
| `/project/addProject` | POST | `project/index.vue` | `addProject.ts` | 见第二节 | `{ message }` | 新建项目 |
| `/project/editProject` | POST | `project/index.vue` | `editProject.ts` | `id`+各字段 | `{ message }` | 编辑项目 |
| `/project/delProject` | POST | `project/index.vue` | `delProject.ts` | `{ id }` | `{ message }` | 删除项目及级联 |
| `/general/getSingleProject` | POST | `stores/index.ts`（路径写错） | `general/getSingleProject.ts` | `{ id }` | 单行数组 | 单项目查询 |
| `/general/updateProject` | POST | 未发现主流程调用 | `general/updateProject.ts` | 部分字段可选 | `{ message }` | 局部更新（旧接口？） |
| `/project/getVisualManual` | POST | `projectDialog.vue` | `getVisualManual.ts` | 无 | 手册列表 | 视觉手册列表 |
| `/project/addVisualManual` | POST | `projectDialog.vue` | `addVisualManual.ts` | name, images, data, stylePath | - | 新增视觉手册 |
| `/project/editVisualManual` | POST | `projectDialog.vue` | `editVisualManual.ts` | 同上 | - | 编辑视觉手册 |
| `/project/deleteVisualManual` | POST | `projectDialog.vue` | `deleteVisualManual.ts` | `{ name }` | - | 删视觉手册 |
| `/project/queryDirectorManual` | POST | `projectDialog.vue` | `queryDirectorManual.ts` | 无 | 手册列表 | 导演手册列表 |
| `/project/addDirectorManual` | POST | `projectDialog.vue` | `addDirectorManual.ts` | 多字段 | - | 新增导演手册 |
| `/project/editDirectorlManual` | POST | `projectDialog.vue` | `editDirectorlManual.ts` | 多字段 | - | 编辑导演手册（拼写 directorl） |
| `/project/deleteDirectorManual` | POST | `projectDialog.vue` | `deleteDirectorManual.ts` | `{ name }` | - | 删导演手册 |
| `/project/getModelDetails` | POST | scriptAgent / production chat | `getModelDetails.ts` | `{ key: "scriptAgent" \| "productionAgent" }` | 模型详情 | Agent 用模型元数据 |
| `/project/visualManual` | POST | 未发现前端直接调用 | `visualManual.ts` | - | - | 需单独读文件（扫描未展开） |
| `/task/getProject` | POST | `views/task/index.vue` | `routes/task/getProject.ts` | - | 任务侧项目列表 | 任务中心用，非主新建链路 |

**未发现**：`createProject` 别名路由、`/project/getProjectDetail` 等。

---

## 九、新功能复用建议

| 需求 | 最小改动点 | 说明 |
|------|------------|------|
| 创建后自动进制作页 | `index.vue` → `addProjectFn` 的 `.then` | 需先 `getAllProject` 找到新 `id`（或让 `addProject` 返回 `id`），再 `project.value = item` + `router.push("/production")` |
| 创建后默认剧本 | `addProject.ts` 或新建 `addProject` 后钩子 | `o_script.insert` + 固定模板内容 |
| 创建后宫格工作区 | 后端 job 目录 + 前端路由 | 挂 `projectId`；勿污染 `scriptAgent` |
| 弹窗加「创建示例剧本」 | `projectDialog.vue` + `addProjectFn` / 后端 | 多一个 boolean，事务内插 `o_script` |
| 项目模板 | `projectDialog` 预设 + `addProject` 默认字段 | 或新表 `o_project_template` |
| 默认画风 / 宫格数 / 总时长 | **优先** 扩 `o_project` 列或 JSON 文本列 | 无 JSON 列时可先用 `intro` 后缀约定（不推荐长期） |
| 项目级配置表 | 新表 `o_project_config(projectId, key, value)` | 迁移成本、与导出 DB 兼容性 |
| 不改 DB 的配置 | `data/{projectId}/config.json` | 与 `delProject` OSS 删除对齐 |

**千万不要轻易改**：

- `ai.ts` / Agent 主决策链（除非明确要接宫格）
- `addProject` 的 `id: Date.now()` 策略（并发可能碰撞，但全链路已依赖）
- 将 `projectId` 仅放 URL 而不写 Pinia（会破坏现有 persist 行为）

**推荐实施顺序**：

1. 只改前端：`addProject` 成功后 `openProject` 式写入 `project` + 跳转  
2. 后端 `addProject` 返回 `{ id }` + 可选默认 `o_script`  
3. 再挂宫格 director / Skill（`projectId` + `scriptId`）

---

## 十、附录：如何调用 Toonflow 新建项目接口

### 1. 前端 UI 使用方法

1. 打开 `http://localhost:50188/#/project`（需已登录或 localDev）
2. 点击右上角 **新建项目**
3. 填写：项目类型、名称、类型、图像/视频模型、比例、简介，并选择视觉手册 + 导演手册
4. 确定 →  toast「添加成功」→ 列表刷新出现新项目
5. **点击卡片** 进入小说/剧本页；顶部菜单可进 ScriptAgent、Production 等

### 2. 前端代码调用示例

```ts
// 与 index.vue addProjectFn 一致
await axios.post("/project/addProject", {
  projectType: "novel",
  name: "测试项目",
  intro: "简介",
  type: "玄幻",
  artStyle: "your_style_path",
  directorManual: "your_director_manual_key",
  videoRatio: "16:9",
  imageModel: "openai:xxx",
  videoModel: "openai:yyy",
  imageQuality: "2K",
  mode: "text",
});
await axios.post("/project/getProject"); // 刷新列表
```

### 3. HTTP 调用示例

**curl：**

```bash
curl -X POST "http://localhost:10588/api/project/addProject" \
  -H "Content-Type: application/json" \
  -H "Authorization: YOUR_TOKEN" \
  -d "{\"projectType\":\"novel\",\"name\":\"API测试\",\"intro\":\"简介\",\"type\":\"玄幻\",\"artStyle\":\"style\",\"directorManual\":\"dir\",\"videoRatio\":\"16:9\",\"imageModel\":\"openai:m\",\"videoModel\":\"openai:v\",\"imageQuality\":\"2K\",\"mode\":\"text\"}"
```

**PowerShell：**

```powershell
$body = @{
  projectType = "novel"
  name = "API测试"
  intro = "简介"
  type = "玄幻"
  artStyle = "style"
  directorManual = "dir"
  videoRatio = "16:9"
  imageModel = "openai:m"
  videoModel = "openai:v"
  imageQuality = "2K"
  mode = "text"
} | ConvertTo-Json

Invoke-RestMethod -Method Post `
  -Uri "http://localhost:10588/api/project/addProject" `
  -ContentType "application/json" `
  -Headers @{ Authorization = "YOUR_TOKEN" } `
  -Body $body
```

### 4. 后端新增接口约定

1. 新建 `Toonflow-app/src/routes/<module>/<action>.ts`
2. `export default router.post("/", ...)`
3. 使用 `success()` / `error()` from `@/lib/responseFormat`
4. `yarn dev` 触发 `core.ts` 再生 `router.ts`

### 5. 新功能获取 projectId

| 方式 | 说明 |
|------|------|
| Pinia | `projectStore().project?.id`（主路径，persist） |
| 列表项 | `getProject` 返回的 `item.id` |
| 接口返回 | 若扩展 `addProject` 返回 `id` |
| 路由 | **当前未使用**；若新增 query 需同步改 `openProject` |

### 6. 常见错误

| 现象 | 原因 |
|------|------|
| 401 / 跳登录 | 无 token 且非 localDev |
| 404 | baseURL 少 `/api` 或后端未启动 |
| 参数错误 | body 缺 Zod 必填字段 |
| 列表不刷新 | 未调 `getAllProject` 或 `allProject` 未绑定 |
| projectId 为空 | 未点选项目就进子页；或 persist 被清空 |
| SQLite ERR_DLOPEN_FAILED | 环境问题，与业务链路无关 |

---

## 扫描完成报告

### 一句话链路

**点击「新建项目」→ 打开 `projectDialog` → 校验表单 → `POST /api/project/addProject` 写 `o_project`（`id=Date.now()`）→ toast → `POST /api/project/getProject` 刷新列表 → 停留列表页；用户点击卡片后 `project` 写入 Pinia 并跳转 `/novel` 或 `/script`，后续 ScriptAgent / Production 通过 `project.id` 与 Socket `auth.projectId` 工作。**

### API 清单摘要

核心 4 个：`getProject`、`addProject`、`editProject`、`delProject`；手册 6+ 个；`general/getSingleProject` 供遗留 store。

### 新功能最推荐复用点

- **HTTP**：继续 `POST /project/addProject` + 扩展返回 `id` 或后处理插 `o_script`
- **上下文**：`stores/project.ts` 的 `project`（persist）
- **Agent**：`projectId` + `scriptId`（production 的 `episodesId`）

### 暂时不要动

- 未使用的 `addProject.vue` 弱校验路径（易与后端不一致）
- `stores/index.ts` 的错误 `getSingleProject` 路径（除非统一修复）
- `userId: 1` 硬编码、 `id: Date.now()` 主键策略（改动需全库评估）

---

*文档仅反映扫描时点源码行为。*
