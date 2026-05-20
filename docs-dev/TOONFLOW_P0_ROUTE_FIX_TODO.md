# Toonflow P0 Route Fix TODO

任务编号：DOC-TOONFLOW-ARCHITECTURE-MAP-CLEANUP

本文档只记录当前只读扫描发现的 P0 风险和建议修复方向，不包含代码修改。

## P0-1 前端调用不存在的 `/video/*` 路由

风险等级：P0

### 现象

前端存在对 `/video/*` 的调用，但后端 `Toonflow-app/src/router.ts` 中没有任何 `/api/video/*` 路由。相关功能一旦触发，会返回 404。

### 涉及文件

```text
Toonflow-web/src/stores/video.ts
```

该文件中可见调用形态：

```text
/video/getVideo
/video/getVideoConfigs
/video/deleteVideoConfig
/video/generateVideo
```

### 当前后端真实路径

后端当前实际视频生成和轮询相关路径集中在：

```text
POST /api/production/workbench/generateVideo
POST /api/production/workbench/batchGenerateVideo
POST /api/production/workbench/checkVideoStateList
POST /api/production/workbench/getVideoList
POST /api/production/workbench/selectVideo
POST /api/production/workbench/delVideo
POST /api/production/workbench/updateVideoPrompt
POST /api/production/workbench/updateVideoDuration
```

后端无：

```text
/api/video/*
```

### 推荐修复方案 A

统一前端调用到 `/production/workbench/*`。

适用场景：

- `/video/*` 是旧代码遗留。
- 当前 UI 可以直接映射到 workbench 的视频表、轨道和轮询模型。

优点：

- 不增加后端兼容层。
- 路由语义与当前后端一致。

风险：

- 需要逐个核对 `stores/video.ts` 的请求体和当前 workbench API schema 是否一致。

### 推荐修复方案 B

新增后端兼容路由 `/api/video/*`，内部转调或复用 `/production/workbench/*` 服务逻辑。

适用场景：

- 仍有旧页面或旧 store 依赖 `/video/*`。
- 希望降低前端改动范围。

优点：

- 对旧前端调用兼容性好。

风险：

- 后端路由数量增加。
- 需要避免两套视频 API 语义分叉。

### 验收方式

- 全仓搜索不再出现未兼容的 `axios.post("/video/` 或 `axios.get("/video/` 调用。
- 打开使用 `stores/video.ts` 的页面，不出现 `/api/video/* 404`。
- 生成视频、查询视频列表、删除视频、轮询状态均可完成。

## P0-2 前端调用旧路径 `/assets/generateAssets`

风险等级：P0

### 现象

前端仍存在旧资产生成路径调用：

```text
/assets/generateAssets
/assets/polishAssetsPrompt
```

但后端真实路由已迁移到 `/assetsGenerate/*`。触发相关旧组件时会 404。

### 涉及文件

```text
Toonflow-web/src/views/assets/components/batchGeneration.vue
```

### 当前后端真实路径

后端实际存在：

```text
POST /api/assetsGenerate/generateAssets
POST /api/assetsGenerate/batchGenerateImageAssets
POST /api/assetsGenerate/polishAssetsPrompt
POST /api/assetsGenerate/batchPolishAssetsPrompt
POST /api/assetsGenerate/cancelGenerate
```

后端无：

```text
POST /api/assets/generateAssets
POST /api/assets/polishAssetsPrompt
```

### 推荐修复方案 A

改前端调用路径：

```text
/assets/generateAssets -> /assetsGenerate/generateAssets
/assets/polishAssetsPrompt -> /assetsGenerate/polishAssetsPrompt
```

优点：

- 与当前后端路由命名保持一致。
- 避免新增兼容路由。

风险：

- 需要核对旧组件请求体是否符合当前 `assetsGenerate` schema。

### 推荐修复方案 B

新增后端兼容路由：

```text
/api/assets/generateAssets
/api/assets/polishAssetsPrompt
```

内部复用 `/api/assetsGenerate/*` 的处理逻辑。

优点：

- 对旧 UI 兼容。

风险：

- 容易长期保留两套路由命名。
- 需要清楚标注 deprecated，避免新代码继续使用旧路径。

### 验收方式

- 全仓搜索不再出现未兼容的 `/assets/generateAssets` 和 `/assets/polishAssetsPrompt`。
- 批量资产生成组件可成功发起生成任务。
- `o_image.state` 能从 `生成中` 流转到 `已完成` 或 `生成失败`。
- 前端轮询 `/api/assets/pollingImageAssets` 能拿到结果。

## P0-3 前端调用 `/setting/skillManagement/scanSkills`

风险等级：P0

### 现象

前端工具函数调用：

```text
/setting/skillManagement/scanSkills
```

但后端 `setting/skillManagement` 下实际只有：

```text
getSkillContent
getSkillList
saveSkillContent
```

因此扫描技能功能会 404。

### 涉及文件

```text
Toonflow-web/src/utils/scanSkills.ts
```

### 当前后端真实路径

后端实际存在：

```text
POST /api/setting/skillManagement/getSkillList
POST /api/setting/skillManagement/getSkillContent
POST /api/setting/skillManagement/saveSkillContent
```

后端无：

```text
POST /api/setting/skillManagement/scanSkills
```

### 推荐修复方案 A

新增后端路由：

```text
POST /api/setting/skillManagement/scanSkills
```

该路由负责扫描 `data/skills`，更新或返回技能列表。

优点：

- 保留前端已有语义。
- 功能边界清晰：`scanSkills` 做扫描，`getSkillList` 做读取。

风险：

- 需要明确扫描是否会写 DB、写 embedding、更新 `o_skillList` 状态。
- 若扫描包含 embedding 生成，可能引入模型依赖和耗时任务。

### 推荐修复方案 B

前端改为调用：

```text
POST /api/setting/skillManagement/getSkillList
```

并移除或降级 `scanSkills` 调用。

优点：

- 不新增后端路由。
- 适合当前后端已经能够返回技能列表的场景。

风险：

- 如果产品预期是“主动重新扫描磁盘技能”，`getSkillList` 不能完全替代。

### 验收方式

- 打开技能管理相关页面，不出现 `/api/setting/skillManagement/scanSkills 404`。
- 技能列表能正常加载。
- 如果采用方案 A，新增扫描后可观察 `o_skillList` 与 `data/skills` 一致。
- 如果采用方案 B，前端不再触发 `scanSkills` 请求。

## P0-4 本地开发鉴权风险

风险等级：P0

### 现象

本地开发免登录依赖前后端两个环境变量同时生效：

```text
后端：TOONFLOW_LOCAL_DEV=1
前端：VITE_TOONFLOW_LOCAL_DEV=1
```

若后端未注入 `TOONFLOW_LOCAL_DEV=1`，除白名单外的 REST 请求会走 JWT 校验。若前端未注入 `VITE_TOONFLOW_LOCAL_DEV=1`，路由守卫会依赖 `localStorage.token`，无 token 时跳转 `/login`。

### 涉及文件

```text
Toonflow-app/src/app.ts
Toonflow-app/src/utils/localMode.ts
Toonflow-web/src/router/index.ts
Toonflow-web/src/utils/localMode.ts
Toonflow-web/.env.development
Toonflow-web/.env.dev
tools/dev/start-toonflow-dev.ps1
```

### 当前后端真实路径

鉴权白名单仅包括：

```text
/api/login/login
/api/gridDirector/health
```

其他 REST 路由都需要：

```text
Authorization token
```

或后端本地开发模式：

```text
TOONFLOW_LOCAL_DEV=1
```

### 推荐修复方案 A

确保 `tools/dev/start-toonflow-dev.ps1` 始终为后端注入：

```text
TOONFLOW_LOCAL_DEV=1
```

同时保留前端 `.env.development` / `.env.dev`：

```text
VITE_TOONFLOW_LOCAL_DEV=1
```

优点：

- 开发体验稳定。
- 与当前脚本设计一致。

风险：

- 需要避免生产或打包环境误注入本地开发变量。

### 推荐修复方案 B

保留鉴权，要求开发者本地先登录获取 token。

优点：

- 更接近生产鉴权路径。

风险：

- 首次初始化时若用户表、tokenKey 或登录流程异常，会阻塞所有开发页面。
- 不适合快速本地联调。

### 验收方式

- 使用开发脚本启动后，访问 `http://localhost:50188` 不跳登录页。
- 请求 `/api/project/getProject` 等非白名单接口不返回 401/444。
- 后端日志中可确认本地开发模式生效。
- 使用 `-NoLocalDev` 或生产启动时，本地免登录不应生效。

## P0-5 Socket URL 不跟随 `setting.baseUrl`

风险等级：P0

### 现象

REST baseUrl 可在 Pinia `setting.baseUrl` 中调整，默认：

```text
http://localhost:10588/api
```

但 Socket 客户端默认写死：

```text
http://localhost:10588
```

当后端换端口、远程访问、反向代理或 Electron 随机端口时，REST 可能能通，但 Socket.IO 会连接错误地址。

### 涉及文件

```text
Toonflow-web/src/utils/axios.ts
Toonflow-web/src/stores/setting.ts
Toonflow-web/src/utils/useSocket.ts
Toonflow-web/src/views/scriptAgent/index.vue
Toonflow-web/src/views/production/components/rightChatBox/index.vue
```

### 当前后端真实路径

Socket.IO 命名空间：

```text
/api/socket/scriptAgent
/api/socket/productionAgent
```

默认后端地址：

```text
http://localhost:10588
```

### 推荐修复方案 A

让 `useSocket` 从 `setting.baseUrl` 推导 Socket origin：

```text
setting.baseUrl = http://host:port/api
socket origin = http://host:port
namespace = /api/socket/scriptAgent 或 /api/socket/productionAgent
```

优点：

- REST 和 Socket 使用同一后端配置来源。
- 支持换端口和远程访问。

风险：

- 需要处理 baseUrl 末尾 `/api`、斜杠、代理 path 等边界。

### 推荐修复方案 B

新增独立配置项：

```text
setting.socketUrl
```

由用户或启动环境单独配置。

优点：

- 可支持 REST 和 Socket 分离部署。

风险：

- 增加一个用户需要理解和维护的配置项。
- 默认值仍需与 dev 脚本保持一致。

### 验收方式

- 修改 REST baseUrl 到非 `localhost:10588` 后，Socket 同步连接到正确地址。
- `/api/socket/scriptAgent` 可正常 `chat`、`stop`。
- `/api/socket/productionAgent` 可正常 `updateContext`、`chat`、`stop`。
- 浏览器 network 面板中不再出现错误的 `localhost:10588/socket.io` 连接。

## 修复优先级建议

```text
P0-1 /video/* 缺失
P0-2 /assets/generateAssets 旧路径
P0-3 /setting/skillManagement/scanSkills 缺失
P0-4 本地开发鉴权变量
P0-5 Socket URL 不跟随 baseUrl
```

建议优先处理会直接 404 的路由缺口，再处理开发环境和 Socket 可配置性。

