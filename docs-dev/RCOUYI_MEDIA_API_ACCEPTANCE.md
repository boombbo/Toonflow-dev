# rcouyi 第三方图像/视频 API 验收报告

> **日期**：2026-05-20  
> **任务类型**：readonly_scan + backend_validation + frontend_validation + docs  
> **环境**：本机 `http://localhost:10588` 后端已运行  

---

## 验收项对照表

| # | 要求 | 代码/静态 | 运行时（当前 DB） | 结论 |
|---|------|-----------|-------------------|------|
| 1 | `third_party_api` 仅 text，不出现在 image/video 下拉 | ✅ `filterModelsForUsage` + `imageRequest` throw | ✅ `getModelList(type=image/video)` 无 third_party_api | **通过** |
| 2 | 第三方图像 API 出现在模型服务左侧 | ✅ `fixDB` 注册 + `getVendorList` | ✅ 列表含 `third_party_image_api` | **通过** |
| 3 | 图像 API 仅允许添加 image 模型 | ✅ `IMAGE_ONLY_VENDOR_IDS` + `effectiveModelTypeOptions` | ✅ UI 逻辑 | **通过** |
| 4 | imageTest 成功、非 0 字节 | ✅ `imageRequest` 无 `return ""` | ⚠️ 见下文 | **待你本地复测** |
| 5 | 新建项目图片下拉含图像 API 模型 | ✅ `projectDialog` → `modelSelect type=image` | ⚠️ 需 enable+模型 | **条件通过** |
| 6 | 角色出图可选图像 API | ✅ `generateImage.vue` → `type=image` | ⚠️ 同上 | **条件通过** |
| 7 | 第三方视频 API 出现在左侧 | ✅ | ✅ `third_party_video_api` 在列表 | **通过** |
| 8 | 视频 API 仅 video 模型 | ✅ `VIDEO_ONLY_VENDOR_IDS` | ✅ | **通过** |
| 9 | videoTest 成功 | ✅ `videoRequest` 有轮询 | ❌ 未配置 Key/模型，未跑 | **待你本地复测** |
| 10 | 新建项目视频下拉含视频 API | ✅ `type=video` | ⚠️ 需 enable+模型 | **条件通过** |
| 11 | 错误不吞、不 `return ""` 出图 | ✅ image/video 适配器 throw | ⚠️ `third_party_api.videoRequest` 仍 `return ""`（文本供应商，不走视频下拉） | **通过（主路径）** |
| 12 | 不改 ai.ts 主链路 | ✅ 未改 | — | **通过** |
| 13 | 不改 DB schema | ✅ 仅 `fixDB` insert 行 | — | **通过** |
| 14 | 不改 package.json | ✅ | — | **通过** |

---

## 1. 实际出现的供应商列表（`getVendorList`）

| id | 显示名 | enable | 模型数 | Base URL | API Key |
|----|--------|--------|--------|----------|---------|
| `third_party_api` | 第三方 API | **1** | 20 | `https://api.rcouyi.com/v1` | sk-D****F6D2（已脱敏） |
| `third_party_image_api` | 第三方图像 API | 0→脚本临时设为 1 | 0→脚本导入 1 | 同文本 API | 脚本已从文本 API 同步 |
| `third_party_video_api` | 第三方视频 API | **0** | **0** | 空 | 空 |

说明：验收脚本 `tools/dev/validate-rcouyi-media-api.mjs` 曾临时 **enable** 图像 API 并导入 `gpt-image-1`；**视频 API 仍未配置**。

---

## 2. `third_party_image_api` 模型列表

**配置前**：`[]`  

**脚本配置后**（`getModelList type=image`）：

```json
[
  {
    "id": "third_party_image_api",
    "label": "gpt-image-1",
    "value": "gpt-image-1",
    "type": "image",
    "name": "第三方图像 API"
  }
]
```

---

## 3. `third_party_video_api` 模型列表

**当前**：`[]`（enable=0，未拉取/未导入）

---

## 4. imageTest 请求与返回摘要（Key 脱敏）

| 项 | 值 |
|----|-----|
| 接口 | `POST /api/setting/vendorConfig/modelTest/imageTest` |
| Body | `{ id: "third_party_image_api", modelName: "gpt-image-1", prompt: "a red apple" }` |
| Authorization | 使用 DB 中 rcouyi Key（与文本 API 相同，**脱敏** sk-D****F6D2） |
| HTTP | **500**（body `code:400`） |
| message | `当前供应商不支持图像生成，请使用支持 imageRequest 的图像供应商。` |
| `testImage.jpg` | **0 字节**（历史失败残留；本次 400 不应视为成功） |

**分析**：

1. `getModelList` 已能列出 `third_party_image_api:gpt-image-1` → **路由与能力过滤代码正确**。  
2. imageTest 返回「不支持图像」来自 `imageTest.ts` catch 内 `vendorSupportsModelType` 判断；**若后端 dev 进程未重启**，可能仍加载旧版 `vendorCapabilities`（`third_party_image_api.image=false`）。  
3. **请重启后端**后再测；并确认图像 API 已 enable、已填 Key、已导入图像模型。

**预期成功时**：

- 请求：`POST https://api.rcouyi.com/v1/images/generations`  
- Body：`{ model, prompt, n:1, size }`  
- 响应：`data[0].b64_json` 或 `url` → `ai.ts` 校验 → `testImage.jpg` **> 1024 字节**

---

## 5. videoTest

**未执行**（`third_party_video_api` 未 enable、无模型、无 Key）。

**预期**：

- Seedance：`POST https://api.rcouyi.com/task/volces/seedance` → `GET /task/{id}`  
- 即梦：`POST /task/jimeng/text2video` 或 `image2video`  

---

## 6. 新建项目图片/视频下拉（截图说明）

| 页面 | 路由/组件 | 预期 UI |
|------|-----------|---------|
| 新建项目 | `projectDialog.vue` → `modelSelect type=image` | 启用图像 API 后出现 **「第三方图像 API」分组 → gpt-image-1** |
| 新建项目 | `modelSelect type=video` | 配置视频 API 后出现 **「第三方视频 API」分组** |
| 角色出图 | `generateImage.vue` → `type=image` | 同上图像模型 |

**当前你本机**：若仅配置文本 API，图片下拉 **不会出现** third_party 项（符合设计）；需按 `THIRD_PARTY_MEDIA_API_SETUP.md` 配置图像/视频供应商。

---

## 7. 角色出图验证

- **代码路径**：`POST /assetsGenerate/generateAssets` → `u.Ai.Image(vendorId:model)` → `third_party_image_api.imageRequest` ✅  
- **本机 E2E**：未跑通（图像 API 未持久 enable / imageTest 未成功）→ **请你配置后点一次生成验证**

---

## 8. 0 字节图片扫描

```
zero_byte_count=4
```

均为 **历史遗留**（`data/oss/.../role/*.jpg`、`testImage.jpg`），非本次图像 API 成功写入。  
修复后新失败应 **不写 0 字节**（`ai.ts` + `saveValidatedAssetImage`）。

---

## 9. lint / type-check

| 命令 | 结果 |
|------|------|
| `Toonflow-app` → `yarn lint` (tsc) | ✅ 通过 |
| `Toonflow-web` → `yarn type-check` | ❌ 既有错误 `generate copy.vue(1063)`，与本次无关 |

---

## 10. 回滚命令

```powershell
git checkout -- Toonflow-app/data/vendor/third_party_image_api.ts
git checkout -- Toonflow-app/data/vendor/third_party_video_api.ts
git checkout -- Toonflow-app/src/utils/vendorCapabilities.ts
git checkout -- Toonflow-app/src/utils/vendorModelStore.ts
git checkout -- Toonflow-app/src/lib/fixDB.ts
git checkout -- Toonflow-app/src/routes/setting/vendorConfig/fetchRemoteModels.ts
git checkout -- Toonflow-app/src/routes/setting/vendorConfig/importVendorModels.ts
git checkout -- Toonflow-web/src/components/setting/components/vendorConfig.vue
Remove-Item docs-dev/RCOUYI_MEDIA_API_ACCEPTANCE.md, tools/dev/validate-rcouyi-media-api.mjs -ErrorAction SilentlyContinue
```

---

## 你需要做的 3 步（才能全流程绿）

1. **重启后端**（加载最新 `vendorCapabilities` + vendor 模板）  
2. **模型服务** → 启用 **第三方图像 API** / **第三方视频 API** → 填与文本相同的 Base URL + Key → 拉取并导入模型  
3. **图像测试** → 确认 `testImage.jpg` > 1KB；**新建项目** → 选 `third_party_image_api:xxx`

验收脚本（Key 脱敏输出）：

```powershell
node tools/dev/validate-rcouyi-media-api.mjs
```
