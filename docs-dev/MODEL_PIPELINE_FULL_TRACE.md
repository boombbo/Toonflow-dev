# Toonflow 模型链路全量追踪

> **日期**：2026-05-20  
> **任务类型**：readonly_scan + backend_api + frontend_ui + docs  
> **结论**：系统缺统一「模型能力注册表」；`o_vendorConfig.models[].type` 与 vendor 模板 `imageRequest/videoRequest` 实现脱节。

---

## 执行阶段确认

| 阶段 | 内容 | 状态 |
|------|------|------|
| 1 | 只读扫描 + 本文档 20 问 | ✅ 已完成 |
| 2 | `vendorCapabilities.ts` 统一规则 | ✅ 已完成 |
| 3 | `third_party_api` 定位为文本供应商 | ✅ 已完成 |
| 4 | `third_party_image_api.ts` 占位 | ✅ 已完成（未写 DB，不自动出现在列表） |
| 5 | `getModelList` / `getImageAndVideoModel` / `vendor.ts` | ✅ 已完成 |
| 6 | Agent 配置 `type=text` | ✅ 原本已是 |
| 7 | `vendorConfig.vue` 提示与测试限制 | ✅ 已完成 |
| 7b | 添加模型：第三方 API 仅禁用 image/video 选项（仍显示）；其它供应商三项可选 | ✅ 2026-05-20 修正 |
| 8 | `formatVendorErrorMessage` + modelTest | ✅ 已完成 |
| 9 | `modelSelect.vue` 空态提示 | ✅ 已完成 |

---

## 20 问答复

### 1. 模型服务页面读取哪个接口？

- **供应商列表**：`POST /api/setting/vendorConfig/getVendorList`  
  前端：`vendorConfig.vue` → `getVendorList()`
- **保存输入**：`updateVendorInputs`
- **拉取远程模型**：`POST /api/setting/vendorConfig/fetchRemoteModels`（仅 `third_party_api`）
- **导入模型**：`POST /api/setting/vendorConfig/importVendorModels`（仅 `third_party_api`，`mergeVendorModelIds` 强制 `type: "text"`）
- **测试**：`modelTest/textTest`、`imageTest`、`videoTest`

### 2. 模型服务里的模型 `type` 从哪里来？

1. 供应商模板 `data/vendor/<id>.ts` 内 `vendor.models` 预置  
2. `o_vendorConfig.models` JSON（用户手动添加 / 远程导入）  
3. `u.vendor.getModelList(id)` 合并两者，`modelName` 去重  
4. **第三方 API 导入**：`vendorModelStore.toTextModelEntry()` 固定 `type: "text"`  
5. **历史误标**：若 DB 中曾有 `image`/`video`，`repairTextOnlyVendorModels("third_party_api")` 会写回为 `text`

### 3. `/models` 拉取后如何判断 text/image/video？

- **当前**：`fetchRemoteModels` **不**根据远程名推断类型，只返回 `remoteModels: string[]`  
- **导入时**：全部 `type: "text"`（`importVendorModels` + `mergeVendorModelIds`）  
- **不应**因名称含 `gpt-image` / `gemini` 自动标为 `image`

### 4. Agent 配置读取哪个接口？

- 选模型：`POST /api/modelSelect/getModelList` `{ type: "text" }`  
- 组件：`agentConfog.vue` → `<modelSelect type="text" />`  
- Agent 部署存储：`o_agentDeploy`（与 vendor 配置分离）

### 5. Agent 配置是否只应显示 text 模型？

**是。** 编剧/导演/分镜 Agent 仅需 `textRequest`。`getModelList` + `filterModelsForUsage(..., "text")` 保证只返回供应商支持文本且 `type=text` 的条目。

### 6. 新建项目图片模型读取哪个接口？

- `projectDialog.vue` → `<modelSelect type="image" />`  
- `POST /api/modelSelect/getModelList` `{ type: "image" }`  
- 过滤：`vendorCapabilities` 要求 vendor 真实 `imageRequest`（非 `return ""` / 非 throw 占位）

### 7. 新建项目视频模型读取哪个接口？

- `<modelSelect type="video" />`  
- 同上，`type: "video"` + `videoRequest` 能力

### 8. 图像生成页面读取哪个接口？

- `generateImage.vue` → `<modelSelect type="image" />`  
- 生成：`POST /api/assetsGenerate/generateAssets` → `u.Ai.Image(...).run().save()`（`ai.ts` 已有空图校验）

### 9. 模型映射页面读取哪个接口？

- `modelMap.vue` → `POST /api/setting/modelMap/getImageAndVideoModel`  
- **修复前 bug**：仅 `filter(m.type === "video")`，图像模型未出现  
- **修复后**：合并 `image` + `video`，并按 `vendorCapabilities` 过滤

### 10–12. 哪些 vendor 实现了 text/image/video？

| vendor | textRequest | imageRequest | videoRequest |
|--------|-------------|--------------|--------------|
| third_party_api | ✅ | ❌ throw | ❌ 空 stub |
| third_party_image_api | ❌ throw | ❌ 未实现 | ❌ |
| null | ✅ | ❌ `return ""` | ❌ `return ""` |
| openai | ✅ | ❌ `return ""` | ❌ `return ""` |
| deepseek | ✅ | ❌ `return ""` | ❌ `return ""` |
| klingai | ✅ | ❌ throw | ✅ |
| grsai, volcengine, vidu, toonflow, minimax, atlascloud | ✅ | ✅ 真实实现 | ✅ 真实实现 |

（自定义 vendor 可通过 `vendorCapabilities.detectCapabilitiesFromCode` 解析模板。）

### 13. third_party_api 当前是否只有 text 能力？

**是。** `imageRequest` 抛错；`videoRequest` 返回 `""`；导入与下拉均按文本处理。

### 14. gpt-image-2 为何出现在第三方 API 模型列表？

- `/v1/models` 返回平台全部模型 ID，名称可含 `gpt-image-2`  
- 模型服务页展示 **已导入** 的条目；导入后 `type=text`，标签仍显示「文本」  
- 名称像图像模型，但 **用途** 在系统内为文本

### 15. 为何不能用于图像生成？

- `getModelList(type=image)` 排除 `third_party_api`  
- 即使 DB 误标 `image`，`sanitizeModelEntry` + `repairTextOnlyVendorModels` 纠正  
- 调用 `imageRequest` 会 throw，且 `ai.ts` 禁止写 0 字节

### 16. 空模板 / OpenAI 模板 / 第三方 API 差异

| 模板 | id | 用途 | imageRequest |
|------|-----|------|--------------|
| 空模板 | `null` | 自定义代码起点 | `return ""` 占位 |
| OpenAI 标准 | `openai` | 官方 OpenAI 文本 + 占位图/视频 | `return ""` |
| 第三方 API | `third_party_api` | OpenAI-Compatible **仅文本** + /models 拉取 | throw |
| 第三方图像 API | `third_party_image_api` | 实验占位，未入 DB 默认 | throw 未实现协议 |

### 17. 「无效令牌」来自哪里？

- 第三方平台 HTTP 401/403 或响应 body  
- `fetchRemoteModels` / `textTest` → `Ai.Text` → 上游返回  
- **常见原因**：Key 与 Base URL 平台不匹配；Key 填进 baseUrl（`fetchRemoteModels` 已拦截 `sk-` 开头 URL）

### 18. 「模型负载已饱和」是否为上游返回？

**是。** 表示请求已到达第三方，上游分组/模型繁忙。`formatVendorErrorMessage` 转为友好文案，**不算**本地配置失败。

### 19–20. 各页面应显示的模型类型

| 页面 | 应显示 |
|------|--------|
| 模型服务 | 全部（按条目 type 展示测试按钮；third_party 仅文本测试） |
| Agent 配置 | 仅 text |
| 新建项目 | image / video 下拉分离 |
| 模型映射 | image + video（有能力者） |
| 图像生成 | 仅 image（有能力者） |

---

## 统一能力模块

**文件**：`Toonflow-app/src/utils/vendorCapabilities.ts`

- `getVendorCapabilities(vendorId)`  
- `filterModelsForUsage(vendorId, models, usage)`  
- `repairTextOnlyVendorModels("third_party_api")`  
- `formatVendorErrorMessage(raw)`

---

## 相关文档

- [IMAGE_GENERATION_ZERO_BYTE_FIX.md](./IMAGE_GENERATION_ZERO_BYTE_FIX.md)
- [MODEL_PROVIDER_MAP.md](./MODEL_PROVIDER_MAP.md)

---

## 验证清单

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/dev/start-toonflow-dev.ps1 -Mode reuse
cd Toonflow-app; corepack yarn lint
```

1. 第三方 API：gpt-5.5 等为文本；仅文本测试  
2. Agent 配置：可见 `third_party_api:xxx`  
3. 新建项目：不出现 `third_party_api` 图像模型；无 image 供应商时空态提示  
4. 图像生成：不选 third_party_api；无 0 字节  
5. 文本测试：负载饱和 / 无效令牌 提示友好
