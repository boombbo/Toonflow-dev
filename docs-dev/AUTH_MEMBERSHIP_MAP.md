# Toonflow 鉴权与会员限制扫描图

> 扫描范围：`Toonflow-app` 与 `Toonflow-web` 中的鉴权、登录、token、会员、订阅、权限相关代码。本文只记录扫描结果，不包含业务代码改动。

## 1. 后端 token 鉴权入口

后端 HTTP token 鉴权入口在 `Toonflow-app/src/app.ts`。

关键位置：

- `src/app.ts` 顶部引入 `jsonwebtoken`。
- `publicApiPaths` 目前包含：
  - `/api/login/login`
  - `/api/gridDirector/health`
- 全局鉴权中间件注册在静态目录之后、路由注册之前：
  - 读取 `o_setting.tokenKey`
  - 从 `req.headers.authorization` 或 `req.query.token` 获取 token
  - 没有 token 时返回 `{"message":"未提供token"}`
  - token 无效时返回 `{"message":"无效的token"}`

结论：所有进入 `src/router.ts` 的 API，默认都会先经过 `src/app.ts` 的 token 中间件，除非在 `publicApiPaths` 中精确白名单。

## 2. “未提供token” 返回位置

`未提供token` 由 `Toonflow-app/src/app.ts` 返回。

触发逻辑：

```ts
if (!token) return res.status(401).send({ message: "未提供token" });
```

这发生在路由执行前，所以即使目标 API 文件存在，也会先被全局鉴权拦截。

## 3. 哪些 API 被全局鉴权影响

受影响范围：

- `Toonflow-app/src/router.ts` 中注册的所有 `/api/**` 路由。
- 当前例外：
  - `/api/login/login`
  - `/api/gridDirector/health`

不受该中间件影响的静态资源：

- `/oss`
- `/skills` 下允许访问的图片文件
- `/assets`
- `data/web` 静态站点

注意：Socket.IO 不走这个 HTTP 中间件；Socket token 校验在各 socket route 内单独实现。

## 4. Socket 鉴权入口

后端 Socket token 校验有两处：

- `Toonflow-app/src/socket/routes/scriptAgent.ts`
- `Toonflow-app/src/socket/routes/productionAgent.ts`

两处模式一致：

- 从 `socket.handshake.auth.token` 读取 token。
- 读取 `o_setting.tokenKey`。
- 调用 `jwt.verify()` 校验。
- token 缺失或无效时 `socket.disconnect()`。

结论：取消本地自用版登录/token 拦截时，除了 HTTP 中间件，还必须处理这两个 Socket 鉴权入口，否则现有 `scriptAgent` 和 `productionAgent` 页面可能无法连接。

## 5. 登录接口与 token 生成

登录接口：

- `Toonflow-app/src/routes/login/login.ts`

行为：

- 校验 `username`、`password`。
- 从 `o_user` 查询用户。
- 成功后读取 `o_setting.tokenKey`。
- 通过 `jwt.sign()` 生成 180 天 token。
- 返回 `success({ token: "Bearer " + token, name, id }, "登录成功")`。

该文件只负责登录和签发 token，不负责全局拦截。

## 6. 前端登录跳转逻辑

前端登录跳转在 `Toonflow-web/src/router/index.ts`。

逻辑：

- `/login` 直接放行。
- 其他路径检查 `localStorage.getItem("token")`。
- 没有 token 时跳转 `/login`。

结论：只取消后端 token 拦截不够；本地模式若不想看到登录页，还需要调整前端路由守卫。

## 7. 前端 token 存储位置

前端 token 存储在 `localStorage`。

写入位置：

- `Toonflow-web/src/pages/login/index.vue`
  - 登录成功后写入：
    - `localStorage.setItem("token", data.token)`
    - `localStorage.setItem("userId", data.id)`

读取位置：

- `Toonflow-web/src/router/index.ts`
  - 用于路由守卫。
- `Toonflow-web/src/utils/axios.ts`
  - 用于 HTTP Authorization。
- `Toonflow-web/src/utils/useSocket.ts`
  - 用于 Socket auth。
- `Toonflow-web/src/utils/useChat.ts`
  - 实际 Agent Socket 连接逻辑中也会注入 auth token。

## 8. axios 如何添加 Authorization

文件：`Toonflow-web/src/utils/axios.ts`

行为：

- 从 `settingStore().baseUrl` 读取 API baseURL。
- 从 `settingStore().otherSetting.axiosTimeOut` 读取 timeout。
- 从 `localStorage.getItem("token")` 读取 token。
- 如果 token 存在，则设置：

```ts
config.headers.Authorization = token;
```

响应 401 时：

- 删除 `localStorage.token`。
- 跳转 `/login`。
- 显示 session expired 提示。

结论：本地模式如果后端不再要求 token，axios 可以保持原状；但若收到 401，仍会跳登录。

## 9. 是否存在会员/订阅/权限判断

扫描关键词：

- `member`
- `membership`
- `vip`
- `subscribe`
- `subscription`
- `plan`
- `pay`
- `license`
- `permission`
- `权限`
- `会员`
- `订阅`

扫描结论：

- 未发现明确的后端会员、订阅、VIP、付费授权拦截逻辑。
- 未发现明确的前端会员、订阅、VIP 页面级拦截逻辑。
- `permission/权限` 命中主要是 Electron 本地数据目录读写权限提示，不是业务权限。
- `license` 命中主要是关于开源 License 的展示。
- `pay/付费策略` 命中主要出现在 `data/skills` 文档中，属于剧本/短剧内容规划概念，不是 Toonflow 软件授权判断。

## 10. 会员限制出现在哪些后端文件

未发现真实会员限制后端文件。

相关但不是会员限制的文件：

- `Toonflow-app/src/app.ts`
  - Electron 数据目录权限检查。
  - HTTP token 鉴权。
- `Toonflow-app/src/routes/setting/vendorConfig/**`
  - 模型供应商启用/禁用配置。
  - 这是本地模型供应商配置，不是会员限制。
- `Toonflow-app/src/routes/setting/modelMap/**`
  - 模型映射与 Prompt 配置。
  - 不是会员限制。

## 11. 会员限制出现在哪些前端文件

未发现真实会员限制前端文件。

相关但不是会员限制的文件：

- `Toonflow-web/src/components/setting/components/about.vue`
  - 展示开源 license 信息。
- `Toonflow-web/src/components/setting/components/vendorConfig.vue`
  - 模型供应商配置 UI。
- 多个页面中的 `disabled` / `limit`
  - 多为 UI 禁用态、分页 limit、文本长度限制，不是会员/订阅限制。

## 12. 最小无鉴权改造方案

目标：本地自用版取消 Toonflow 自己的登录、token、权限拦截，但不删除原代码、不绕过第三方模型 API 付费、不写死密钥。

建议采用环境变量开关：

- 后端：`TOONFLOW_LOCAL_DEV=1`
- 前端：`VITE_TOONFLOW_LOCAL_DEV=1`

后端最小改造：

- 新增 `Toonflow-app/src/utils/localMode.ts`。
- 在 `Toonflow-app/src/app.ts` 的全局 HTTP 鉴权中间件开头：
  - 如果本地模式开启，直接 `next()`。
  - 保留原 JWT 代码。
- 在 `Toonflow-app/src/socket/routes/scriptAgent.ts`：
  - 如果本地模式开启，跳过 token 校验。
  - 仍要求 `isolationKey`。
- 在 `Toonflow-app/src/socket/routes/productionAgent.ts`：
  - 如果本地模式开启，跳过 token 校验。
  - 仍要求 `isolationKey`，保留 `projectId/scriptId` 上下文。

前端最小改造：

- 新增 `Toonflow-web/src/utils/localMode.ts`。
- 在 `Toonflow-web/src/router/index.ts`：
  - 本地模式开启时，不因缺 token 跳转 `/login`。
- 在 `Toonflow-web/src/pages/login/index.vue`：
  - 本地模式显示“本地开发模式已启用”。
  - 提供进入工作台按钮。
  - 不删除原登录表单代码。
- 可选：在 `Toonflow-web/src/utils/axios.ts` 中，本地模式下 401 不强制跳登录。但这一步要谨慎，避免吞掉真实接口错误。

## 13. 风险点

- HTTP API 与 Socket.IO 鉴权是两套入口，必须分别处理。
- 只改后端不改前端，前端路由仍会因无 token 跳登录。
- 只改前端不改后端，API 仍会返回 `未提供token`。
- 本地模式必须默认关闭，避免正式运行时无鉴权。
- 不应扩大到第三方模型授权，不应伪造供应商 token，不应写死 API key。
- 现有 `publicApiPaths` 只适合少量公开接口；本地全局无鉴权应使用显式环境变量，而不是把所有 API 加白名单。
- 当前 `GET /api/gridDirector/health` 已存在，但是否被拦截取决于 `publicApiPaths` 和运行中代码版本。

## 14. 建议修改文件清单

后端：

- `Toonflow-app/src/utils/localMode.ts`
- `Toonflow-app/src/app.ts`
- `Toonflow-app/src/socket/routes/scriptAgent.ts`
- `Toonflow-app/src/socket/routes/productionAgent.ts`

前端：

- `Toonflow-web/src/utils/localMode.ts`
- `Toonflow-web/src/router/index.ts`
- `Toonflow-web/src/pages/login/index.vue`
- 可选：`Toonflow-web/src/utils/axios.ts`

不建议修改：

- `package.json`
- 原有 `login.ts` 登录接口
- 原有 `scriptAgent` / `productionAgent` 主流程
- 第三方模型供应商配置与 API key 逻辑
