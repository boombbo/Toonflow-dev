# rcouyi 媒体供应商 UI/API 验收报告

> **日期**：2026-05-20  
> **任务类型**：readonly_scan + runtime_api_verify（**未修改任何 `.ts` / `.vue` / `package.json` / `yarn.lock`**）  
> **后端**：`http://localhost:10588`（`TOONFLOW_LOCAL_DEV=1`，Node 22 + `better-sqlite3` 已按 MODULE 127 重建）  
> **验收脚本**：`.toonflow-dev/rcouyi-ui-verify-run.mjs`（一次性 runner，非业务代码）

---

## 0. 环境与重启

| 项 | 结果 |
|----|------|
| `start-toonflow-dev.ps1 -Mode restart -Force` | 已执行；首次因 **Node 24 vs 22** 导致 `better-sqlite3` `ERR_DLOPEN_FAILED`，DB 接口 500 |
| 修复 | 使用 **Cursor 自带 Node 22**（`MODULE_VERSION=127`）执行 `npm rebuild better-sqlite3` 后，`corepack yarn dev` 正常 |
| 建议 | 本机开发统一用 **同一 Node 大版本** 启动后端并编译 native 模块；PATH 中 Node 24 与 Node 22 混用会复现 |

---

## 1. 模型服务左侧供应商（`getVendorList`）

| id | 显示名 | enable | 模型数 | baseUrl（脱敏后） |
|----|--------|--------|--------|-------------------|
| `third_party_api` | 第三方 API | 1 | 8 | `https://api.rcouyi.com/v1` |
| `third_party_image_api` | 第三方图像 API | 1 | 2 | `https://api.rcouyi.com/v1` |
| `third_party_video_api` | 第三方视频 API | 1 | 1 | `https://api.rcouyi.com/v1` |

**结论**：✅ 三项均在列表中出现（对应 UI「模型服务」左侧）。

---

## 2. `third_party_image_api` 配置（API 写入后回读）

| 字段 | 期望值 | 实际（`updateVendorInputs` 后） |
|------|--------|----------------------------------|
| baseUrl | `https://api.rcouyi.com/v1` | ✅ 一致 |
| apiKey | （与文本 API 相同） | ✅ 已同步（报告中仅 `sk-D****F6D2`） |
| providerMode | `openai_images` | ✅ |
| submitPath | `/images/generations` | ✅ |
| 模型 | `gpt-image-1`，type=image | ✅ DB 中另有 `gpt-image-2` |

---

## 3. imageTest（`POST /api/setting/vendorConfig/modelTest/imageTest`）

| 项 | 值 |
|----|-----|
| 请求 | `{ id: "third_party_image_api", modelName: "gpt-image-1", prompt: "a simple red apple on white background" }` |
| HTTP | **502**（body `code: 400`） |
| message | `图像生成失败 HTTP 400: size not supported for this image model`（rcouyi `size_not_supported`） |
| `data/oss/testImage.jpg` | **0 字节**（历史失败残留；本次未产生有效图） |
| 是否返回有效图片 | ❌ **否**（上游拒绝尺寸，非静默成功） |

**补充**：`gpt-image-2` 复测同样未返回有效图（快速失败，`testImage.jpg` 仍为 0 字节）。

**结论**：

- ✅ 供应商能力识别、路由、Key 下发正常（能打到 rcouyi）。
- ❌ **当前 Key/模型组合下 `gpt-image-1` + 测试页默认 `1K` 尺寸映射不被 rcouyi 接受**；需在 UI 调整 `defaultSize` 或换模型后再测。
- ✅ 失败时返回 **明确 HTTP 错误**，未出现「接口 200 + 空图完成」。

---

## 4. `third_party_video_api` 配置（API 写入后回读）

| 字段 | 期望值 | 实际 |
|------|--------|------|
| taskRoot | `https://api.rcouyi.com` | ✅ |
| providerMode | `seedance_volces` | ✅ |
| submitPath | `/task/volces/seedance` | ✅ |
| pollPathTemplate | `/task/{task_id}` | ✅ |
| 模型 | `doubao-seedance-1-5-pro-251215`，type=video | ✅ |

---

## 5. videoTest（`POST /api/setting/vendorConfig/modelTest/videoTest`）

| 项 | 值 |
|----|-----|
| 请求 | `{ id: "third_party_video_api", modelName: "doubao-seedance-1-5-pro-251215", mode: "text", prompt: "a cat walking on grass, cinematic", images/videos/audios: [] }` |
| HTTP | **400** |
| message | `submitPath 配置错误或接口不存在（POST /task/volces/seedance HTTP 404）`；rcouyi 返回 `Invalid URL` |
| task_id | 无（提交失败） |
| 最终视频 URL | 无 |
| `data/oss/test.mp4` | **0 字节** |

**结论**：❌ 当前账号/网关下 **`POST https://api.rcouyi.com/task/volces/seedance` 返回 404**；需对照 rcouyi 控制台确认 Seedance 路径是否开通，或改用 `jimeng` / `kling` / `custom` 路径。错误信息已透传，未假成功。

---

## 6. 新建项目下拉（`POST /api/modelSelect/getModelList`）

| 检查项 | 结果 |
|--------|------|
| 图片模型含 `third_party_image_api:gpt-image-1` | ✅ |
| 图片模型含 `third_party_image_api:gpt-image-2` | ✅ |
| 视频模型含 `third_party_video_api:doubao-seedance-1-5-pro-251215` | ✅ |
| `third_party_api` 出现在 image/video 下拉 | ✅ **未出现**（仅 text 列表） |

**结论**：✅ 与「文本 / 图像 / 视频三供应商分离」设计一致。

---

## 7. 新建角色出图（`generateAssets`）

| 项 | 结果 |
|----|------|
| 使用项目 | 脚本新建项目 / 既有项目 `1779207160677` |
| 阻塞 | 脚本新建项目后 `generateAssets` 返回「项目为空」（`addProject` 与查询时序/DB 需人工在 UI 再确认） |
| 既有项目 + 新角色 | 未在本轮完整跑通（PowerShell 内联脚本转义问题）；**imageTest 已证明上游可连通** |

**0 字节防护（与本轮 imageTest 失败相关）**：

- 失败时 rcouyi 返回 400 → 后端应 **不写完成态**（见 `ai.ts` / `saveValidatedAssetImage` 链路）。
- 全库扫描 0 字节图片：**4 个**（均为历史 `role/*.jpg`、`testImage.jpg`），**本轮未新增成功写入的 0 字节业务图**。

```powershell
Get-ChildItem -Recurse ".\Toonflow-app\data\oss" -Include *.jpg,*.jpeg,*.png,*.webp |
  Where-Object { $_.Length -eq 0 } |
  Select-Object FullName, Length, LastWriteTime
# Count = 4
```

---

## 8. 验收项总表

| # | 要求 | 结果 |
|---|------|------|
| 1 | 重启后端 | ⚠️ 需 Node 22 重建 sqlite；手动 `yarn dev` 后可用 |
| 2 | 左侧出现三个 third_party 供应商 | ✅ |
| 3 | 配置 `third_party_image_api`（openai_images + submitPath） | ✅ 已持久化 |
| 4 | imageTest 有效图 | ❌ `size_not_supported`（gpt-image-1） |
| 5 | 配置 `third_party_video_api`（seedance + poll） | ✅ 已持久化 |
| 6 | videoTest 成功 | ❌ HTTP 404（路径/权限） |
| 7 | 新建项目 image/video 下拉 | ✅ |
| 8 | 角色出图不产生 0 字节 | ⚠️ 未 E2E 成功；失败路径有明确错误；历史 0 字节 4 个 |
| 9 | 不改业务代码 | ✅ |

---

## 9. 建议你本地 UI 复测的 3 步

1. **模型服务 → 第三方图像 API**：确认 `providerMode=openai_images`、`submitPath=/images/generations`；图像测试改用 **`gpt-image-2`** 或在供应商配置填 `defaultSize=1024x1024` 后再测 `gpt-image-1`。
2. **模型服务 → 第三方视频 API**：向 rcouyi 确认 Seedance 任务 URL；若 404 持续，尝试 `providerMode=jimeng` 或控制台给出的 `submitPath`。
3. **新建剧情 → 角色 → 生成图片**：DevTools 勾选 Disable cache；删除历史 0 字节记录后重生成；成功时 `/oss/...` 文件应 **> 1024 字节**，ETag 不应为 `W/"0-..."`。

---

## 10. 复现命令

```powershell
# 统一 Node 22（示例：Cursor 自带）
$env:PATH = "c:\Program Files\cursor\resources\app\resources\helpers;$env:PATH"
cd D:\ComfyUIApi\16宫格分镜_\BBBBBBBBBBBB\Toonflow-app
npm rebuild better-sqlite3

# 启动
cd ..
powershell -NoProfile -ExecutionPolicy Bypass -File tools\dev\start-toonflow-dev.ps1 -Mode restart -Force

# API 验收（Key 脱敏输出）
node .toonflow-dev/rcouyi-ui-verify-run.mjs
```

---

## 11. 相关文档

- `docs-dev/RCOUYI_MEDIA_API_ACCEPTANCE.md`（代码向验收）
- `docs-dev/THIRD_PARTY_MEDIA_API_SETUP.md`（配置说明）
- `docs-dev/IMAGE_GENERATION_ZERO_BYTE_FIX.md`（0 字节修复说明）

---

## 12. P1-RCOUYI-MEDIA-PARAM-FIX（2026-05-20）

> **任务**：修复 rcouyi 图像 `size` 映射与视频路径配置体验  
> **未改**：`ai.ts`、`productionAgent`、`scriptAgent`、DB schema、`package.json` / `yarn.lock`

### 12.1 修改摘要

| 区域 | 改动 |
|------|------|
| `third_party_image_api.ts` | `resolveOpenAiPixelSize`：defaultSize → openAiSize → size/aspectRatio 映射 → `1024x1024`；`size_not_supported` 友好错误 |
| `imageTest.ts` | 默认 `aspectRatio=1:1`；支持 body `openAiSize` |
| `ImageModelTest.vue` | 第三方图像 API 测试页尺寸下拉（1024×1024 / 1024×1536 / 1536×1024） |
| `third_party_video_api.ts` | 404/Invalid URL 明确提示 taskRoot/submitPath/通道开通 |
| `VideoModelTest.vue` / `vendorConfig.vue` | 视频路径配置说明与错误提示增强 |
| `modelTestHttp.ts` | size/路径类错误归类为 HTTP 400 |

### 12.2 图像 size 最终映射（openai_images）

优先级（高 → 低）：

1. 供应商 `inputValues.defaultSize`（模板默认 `1024x1024`）
2. 测试请求 / 调用方 `openAiSize`（如 `1024x1024`）
3. `mapImageSize(config.size, config.aspectRatio)`（如 `1K` + `1:1` → `1024x1024`）
4. 安全默认 **`1024x1024`**

**不再**将 imageTest 默认 `1K` + `16:9` 隐式映射为 `1792x1024`（此前触发 rcouyi `size_not_supported`）。

### 12.3 imageTest 新结果（重启后端后 API）

| 项 | 值 |
|----|-----|
| 请求 | `gpt-image-1` + `openAiSize=1024x1024` + `aspectRatio=1:1` |
| HTTP | **200** |
| `data/oss/testImage.jpg` | **1,532,721 字节**（有效 JPEG） |
| 失败时 | 返回含 `defaultSize` / 尺寸建议的 **400** 文案；`save` 前校验，不写 0 字节 |

### 12.4 videoTest 新结果

| 项 | 值 |
|----|-----|
| 配置 | `taskRoot=https://api.rcouyi.com`，`submitPath=/task/volces/seedance` |
| HTTP | **400**（非假成功） |
| message | 含「当前任务提交路径不可用…请检查 taskRoot、submitPath…是否开通对应视频通道」 |
| `test.mp4` | 仍为历史 **0 字节**（提交失败未调用 `save`；需用户在 rcouyi 控制台确认 Seedance 路径或改用 jimeng/kling） |

### 12.5 新建项目下拉（复测）

| 检查项 | 结果 |
|--------|------|
| image 含 `third_party_image_api` 模型 | ✅（`getModelList` 返回 id=`third_party_image_api`） |
| video 含 `third_party_video_api` 模型 | ✅（DB 已配置时） |
| `third_party_api` 出现在 image/video | ✅ **未出现** |

### 12.6 lint

```text
cd Toonflow-app && corepack yarn lint  → Done (tsc --noEmit)
```

### 12.7 复现命令

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\dev\start-toonflow-dev.ps1 -Mode restart -Force
cd Toonflow-app  # 或仓库根
node .toonflow-dev/p1-rcouyi-param-verify.mjs
```

### 12.8 回滚

```powershell
git checkout -- Toonflow-app/data/vendor/third_party_image_api.ts
git checkout -- Toonflow-app/data/vendor/third_party_video_api.ts
git checkout -- Toonflow-app/src/routes/setting/vendorConfig/modelTest/imageTest.ts
git checkout -- Toonflow-app/src/utils/modelTestHttp.ts
git checkout -- Toonflow-web/src/components/setting/components/vendorTest/ImageModelTest.vue
git checkout -- Toonflow-web/src/components/setting/components/vendorTest/VideoModelTest.vue
git checkout -- Toonflow-web/src/components/setting/components/vendorConfig.vue
git checkout -- docs-dev/RCOUYI_MEDIA_API_UI_VERIFY.md
```
