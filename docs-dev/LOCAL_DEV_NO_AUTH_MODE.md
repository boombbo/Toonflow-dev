# Toonflow 本地自用无鉴权模式

## 1. 功能说明

本地自用无鉴权模式用于 Toonflow 二次开发期间跳过 Toonflow 本地应用自己的登录、HTTP token 校验和 Agent Socket token 校验。

开启后：

- 后端 HTTP API 不再因为缺少 token 返回 `未提供token`。
- `scriptAgent` Socket 不再因为缺少 token 断开。
- `productionAgent` Socket 不再因为缺少 token 断开。
- 前端没有 `localStorage.token` 时不再强制跳转 `/login`。
- 登录页仍然保留，并额外显示“本地开发模式已启用，可直接进入工作台。”

该模式不会绕过第三方模型供应商 API key，也不会写死任何密钥。

## 2. 后端开关

后端环境变量：

```powershell
$env:TOONFLOW_LOCAL_DEV="1"
```

只有 `TOONFLOW_LOCAL_DEV=1` 时开启。默认不开启。

## 3. 前端开关

前端环境变量：

```env
VITE_TOONFLOW_LOCAL_DEV=1
```

已在以下文件写入：

- `Toonflow-web/.env.dev`
- `Toonflow-web/.env.development`

说明：当前 `yarn dev` 使用 Vite 默认开发模式，会读取 `.env.development`；`.env.dev` 保留给显式 `--mode dev` 场景。

## 4. Windows PowerShell 启动方式

后端：

```powershell
cd D:\ComfyUIApi\16宫格分镜_\BBBBBBBBBBBB\Toonflow-app
$env:TOONFLOW_LOCAL_DEV="1"
yarn dev
```

前端：

```powershell
cd D:\ComfyUIApi\16宫格分镜_\BBBBBBBBBBBB\Toonflow-web
yarn dev
```

访问：

```text
http://localhost:50188
```

## 5. 修改文件清单

后端：

- `Toonflow-app/src/utils/localMode.ts`
- `Toonflow-app/src/app.ts`
- `Toonflow-app/src/socket/routes/scriptAgent.ts`
- `Toonflow-app/src/socket/routes/productionAgent.ts`

前端：

- `Toonflow-web/src/utils/localMode.ts`
- `Toonflow-web/src/router/index.ts`
- `Toonflow-web/src/pages/login/index.vue`
- `Toonflow-web/src/utils/axios.ts`
- `Toonflow-web/.env.dev`
- `Toonflow-web/.env.development`

文档：

- `docs-dev/LOCAL_DEV_NO_AUTH_MODE.md`

## 6. 安全边界

- 只跳过 Toonflow 本地 HTTP/JWT/Socket token 鉴权。
- 不删除原登录接口。
- 不删除原 JWT 校验逻辑。
- 不修改第三方模型供应商配置。
- 不伪造外部云服务授权。
- 不写死 API key、token 或密钥。
- 不新增 `gridDirector` 独立任务接口。
- 本地模式必须由环境变量显式开启，默认关闭。

## 7. 如何关闭本地模式

后端关闭：

```powershell
Remove-Item Env:\TOONFLOW_LOCAL_DEV
```

或重新打开一个未设置该环境变量的 PowerShell。

前端关闭：

- 删除或注释 `Toonflow-web/.env.dev` 中的 `VITE_TOONFLOW_LOCAL_DEV=1`。
- 删除或注释 `Toonflow-web/.env.development` 中的 `VITE_TOONFLOW_LOCAL_DEV=1`。
- 重启 `yarn dev`。

## 8. 回滚方式

删除新增文件：

- `Toonflow-app/src/utils/localMode.ts`
- `Toonflow-web/src/utils/localMode.ts`
- `Toonflow-web/.env.dev`
- `Toonflow-web/.env.development`
- `docs-dev/LOCAL_DEV_NO_AUTH_MODE.md`

还原修改文件：

- `Toonflow-app/src/app.ts`
- `Toonflow-app/src/socket/routes/scriptAgent.ts`
- `Toonflow-app/src/socket/routes/productionAgent.ts`
- `Toonflow-web/src/router/index.ts`
- `Toonflow-web/src/pages/login/index.vue`
- `Toonflow-web/src/utils/axios.ts`

如果使用 Git，可查看差异后按文件回退本阶段改动，不需要回退此前已有的 `gridDirector/health` 或扫描文档。
