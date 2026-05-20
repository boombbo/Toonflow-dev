# better-sqlite3 Native 模块 ABI 错配恢复 SOP

> **任务编号**：P0-SQLITE-RECOVERY-DOC  
> **类型**：长期运维 / 开发环境  
> **适用项目**：`Toonflow-app`（Knex + `better-sqlite3`）  
> **最后验证**：2026-05-20

---

## 1. 问题现象

后端已监听端口（如 `10588`），但**所有依赖 SQLite 的 API** 返回 500，响应体常为：

```json
{ "code": "ERR_DLOPEN_FAILED" }
```

后端日志典型错误：

```text
Error: The module '...\better-sqlite3\build\Release\better_sqlite3.node'
was compiled against a different Node.js version using
NODE_MODULE_VERSION 137. This version of Node.js requires
NODE_MODULE_VERSION 127.
```

或反向（运行 Node 24、binding 为 Node 22 编译时）。

**连带现象**（本次会话中曾出现）：

- `start-toonflow-dev.ps1 -Mode restart -Force` 健康检查超时（实为 DB 不可用，非端口未起）
- `getVendorList` / `getProject` 等接口 500
- `Invoke-RestMethod` 报 `ERR_DLOPEN_FAILED`

**本质**：`better-sqlite3` 的 **native binding（`.node` 文件）与当前进程的 Node ABI 不一致**。

---

## 2. 根因

| 因素 | 说明 |
|------|------|
| 当前运行 Node | **v22.22.0**，`process.versions.modules` = **127** |
| 错误 binding | 曾为 **Node 24** 编译，`NODE_MODULE_VERSION` = **137** |
| PATH 混用 | 本机同时存在 **Cursor 自带 Node 22** 与 **系统 `C:\Program Files\nodejs` Node 24**；`where node` 顺序决定 `yarn dev` / `npm rebuild` 用哪套 ABI |
| 文件占用 | 后端进程加载 `better_sqlite3.node` 时，`npm rebuild` 可能报 `EBUSY` / `EPERM`，需先释放 10588 端口再重建 |

**对照表**（Windows x64，常见版本）：

| Node 主版本 | `process.versions.modules` |
|-------------|----------------------------|
| Node 22 | **127** |
| Node 24 | **137** |

---

## 3. 诊断命令（按顺序执行）

### 3.1 确认当前 Node 与 ABI

```powershell
node -v
where.exe node
node -e "console.log(process.versions)"
```

关注输出中的 **`modules`** 字段（即 ABI 号）。

### 3.2 确认 binding 文件存在

```powershell
cd Toonflow-app
Get-ChildItem node_modules\better-sqlite3\build\Release\
```

应看到 `better_sqlite3.node`。若无 `prebuilds/`，一般为本地编译产物。

### 3.3 验证模块能否加载

```powershell
cd Toonflow-app
node -e "const db = require('better-sqlite3'); console.log('OK', typeof db);"
```

| 结果 | 含义 |
|------|------|
| `OK function` | binding 与当前 `node` 一致 |
| `ERR_DLOPEN_FAILED` | 需执行下文「修复命令」 |

---

## 4. 修复命令（仅 rebuild better-sqlite3）

### 4.1 固定 PATH（推荐，与 `yarn dev` 一致）

开发会话开头执行一次（**仅当 PATH 可能混用 Node 24 时**）：

```powershell
$env:PATH = "c:\Program Files\cursor\resources\app\resources\helpers;$env:PATH"
```

> 路径以本机 Cursor 安装为准；`where node` 第一项应为 Node **22**。

### 4.2 释放占用（若 rebuild 报 EBUSY）

后端运行中会锁定 `better_sqlite3.node`。先停 Toonflow 后端（10588），例如：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\dev\stop-toonflow-dev.ps1 -Force
```

若端口仍被占用，再查 PID 并仅结束对应监听进程（勿误杀无关服务）。

### 4.3 重建 native 模块

```powershell
cd Toonflow-app
npm rebuild better-sqlite3
```

期望：`rebuilt dependencies successfully`

### 4.4 关于 `yarn rebuild`（本项目不可用）

```powershell
corepack yarn rebuild better-sqlite3
# → error Command "rebuild" not found.
```

**原因**：本项目使用 **Yarn 1**，**没有** `yarn rebuild` 子命令。  
**正确做法**：使用上节 **`npm rebuild better-sqlite3`**（只编译该包，不改动 lock 文件逻辑）。

### 4.5 何时需要 `--build-from-source`

仅当 `npm rebuild` 报缺少编译工具链（Python / VS Build Tools）时：

```powershell
cd Toonflow-app
npm rebuild better-sqlite3 --build-from-source
```

前置：本机安装 **Visual Studio Build Tools（C++ 工作负载）** 与 Python。  
若仍失败：停止操作，由人工决定切换 Node 版本（nvm/fnm）或安装构建工具。

---

## 5. 禁止事项（修复过程中）

| 禁止 | 原因 |
|------|------|
| 修改 `package.json` | 非本 SOP 范围 |
| 修改 `yarn.lock` | 避免依赖漂移 |
| `yarn install` / `npm install` 重装全部依赖 | 易动 lock、耗时长、引入无关变更 |
| 删除整个 `node_modules` | 同上 |
| 为绕过问题改业务 `.ts` / `.vue` | 根因在 native binding |
| 每次日常启动都跑 `npm rebuild` | 仅 ABI 错配时执行 |

---

## 6. 验证命令

### 6.1 模块加载（本地）

```powershell
cd Toonflow-app
node -e "const db = require('better-sqlite3'); console.log('OK', typeof db);"
```

### 6.2 启动开发环境

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\dev\start-toonflow-dev.ps1 -Mode reuse
# 或需要干净重启时：
# powershell -NoProfile -ExecutionPolicy Bypass -File tools\dev\start-toonflow-dev.ps1 -Mode restart -Force
```

### 6.3 HTTP API（需 DB 的接口不应再 500）

```powershell
Invoke-WebRequest -Uri "http://localhost:10588/api/gridDirector/health" -UseBasicParsing
Invoke-WebRequest -Uri "http://localhost:10588/api/project/getProject" -Method POST -ContentType "application/json" -Body "{}" -UseBasicParsing
```

| 接口 | 期望 |
|------|------|
| `GET /api/gridDirector/health` | **200** |
| `POST /api/project/getProject` | **200**（`data` 可为空数组，但**不是** 500 / `ERR_DLOPEN_FAILED`） |

---

## 7. 本次已成功结果（存档）

| 项 | 值 |
|----|-----|
| Node | **v22.22.0** |
| ABI | **127** |
| `better-sqlite3` 加载 | `OK function` |
| `health` | **200** |
| `getProject` | **200** |
| 修复命令 | `npm rebuild better-sqlite3`（`yarn rebuild` 不可用） |

---

## 8. PATH 与日常开发约定

### 8.1 长期标准（ABI 错配时执行一次）

```powershell
$env:PATH = "c:\Program Files\cursor\resources\app\resources\helpers;$env:PATH"
cd Toonflow-app
npm rebuild better-sqlite3
```

### 8.2 日常启动（不需要每次 rebuild）

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\dev\start-toonflow-dev.ps1 -Mode reuse
```

仅在以下情况再跑 `npm rebuild better-sqlite3`：

- 升级 / 切换 Node 主版本后
- 出现 `ERR_DLOPEN_FAILED` / `NODE_MODULE_VERSION` 日志
- 拉取依赖后 `better_sqlite3.node` 被替换成错误 ABI 的预编译包

### 8.3 避免混用

- **开发 `yarn dev`**：优先 Cursor Node **22**（abi127）
- **系统 Node 24**：不要与 Toonflow 后端混用同一 `node_modules` 下的 `better-sqlite3`，除非已用 Node 24 重新 `npm rebuild better-sqlite3`

---

## 9. 与启动脚本的关系

`tools/dev/start-toonflow-dev.ps1` 已支持日志轮转与健康检查；**native 错配仍需按本文 SOP 处理**，启动脚本不能代替 `npm rebuild`。

若重启时报日志占用，脚本会尝试归档 `backend.log`；归档失败时写入带时间戳的新日志文件，不应再因日志锁导致整脚本崩溃（见 P0-2-FIX-STARTER）。

---

## 10. 回滚方式

本文档为**纯文档**，无代码变更。若误执行 `npm rebuild` 后仍异常：

1. 确认 `node -v` 与重建时使用的 `node` 为同一二进制（`where node` 第一项）
2. 停止后端后再次 `npm rebuild better-sqlite3`
3. 仍失败：由人工决定是否用 nvm/fnm 统一 Node 版本，或从备份恢复 `node_modules\better-sqlite3`（不推荐整库重装）

删除本文档即可撤销文档层面变更：

```powershell
Remove-Item docs-dev\SQLITE_NATIVE_MODULE_RECOVERY.md
```

---

## 11. 相关文档

- `docs-dev/TOONFLOW_DEV_LAUNCHER.md` — 开发启动说明
- `docs-dev/RCOUYI_MEDIA_API_UI_VERIFY.md` — rcouyi 媒体 API UI 验收（需 DB 正常后执行）
- `tools/dev/README.md` — 启动脚本参数

---

## 12. 修复后下一步（主线）

环境恢复后，可继续 **P1-RCOUYI-MEDIA-UI-VERIFY**：

1. `start-toonflow-dev.ps1 -Mode restart -Force`（或 `-Mode reuse`）
2. 模型服务：第三方图像 API → `imageTest`；第三方视频 API → `videoTest`
3. 新建项目 image/video 下拉、新建角色出图
4. 确认不再产生新的 0 字节 OSS 图片（见 `docs-dev/IMAGE_GENERATION_ZERO_BYTE_FIX.md`）
