# gpt-image-2 图生图 /images/edits 实现说明

> **任务编号**：P1-GPT-IMAGE2-I2I-EDITS-IMPLEMENT  
> **类型**：backend_vendor_patch + minimal_ui_hint + docs  
> **日期**：2026-05-20

---

## 1. 修改文件清单

| 文件 | 变更 |
|------|------|
| `Toonflow-app/data/vendor/third_party_image_api.ts` | 新增 `imageRequestViaEdits`、分流、`editPath` 配置、edits 错误与日志 |
| `Toonflow-app/src/utils/vm.ts` | 沙箱注入 `Buffer`（multipart 参考图解码） |
| `Toonflow-web/.../vendorTest/ImageModelTest.vue` | 图生图 tab 一行提示 |
| `docs-dev/GPT_IMAGE2_I2I_EDITS_IMPLEMENT.md` | 本文档 |

**未修改**：`ai.ts`、DB schema、`package.json` / `yarn.lock`、`productionAgent` / `scriptAgent`

---

## 2. 为什么 generations 不是真图生图

此前链路（见 `GPT_IMAGE2_I2I_PROVENANCE_TRACE.md`）：

1. 前端上传 `imageBase64` → 后端 `referenceList` → `Ai.Image().run()`
2. Vendor `imageRequestViaGenerations` 仅 POST JSON：`model/prompt/size/...`
3. **body 无 `image` 字段** → 上游按文生图处理，参考图未参与生成

---

## 3. referenceList 已到 vendor 的证据

- `imageTest.ts`：`referenceList = [{ type: "image", base64: imageBase64 }]`
- `ai.ts`（只读）：vendor ≥2.0 保留 `referenceList` 传入 `imageRequest`
- 日志：`[imageTest][start] hasReferenceImage=true`、`referenceImageBytes>0`

---

## 4. edits 触发条件

同时满足：

| 条件 | 说明 |
|------|------|
| `providerMode === "openai_images"` | 默认第三方图像 API |
| `referenceList.length > 0` | 有参考图 |
| `model.modelName` 含 `gpt-image` | 含 gpt-image-2、gpt-image-1.5 等 |
| **不**命中 `usesChatImageEndpoint` | gemini 等仍走 chat |

**不触发 edits**：

- 无参考图 → `/images/generations`
- `providerMode === "custom"` → 仍走 generations（不强行 edits）
- `kling_images` → 原 Kling 逻辑

---

## 5. multipart 字段表

`POST {baseURL}{editPath}`，默认 `editPath=/images/edits`

| 字段 | 来源 |
|------|------|
| `image` | `referenceList[0].base64` → Buffer 文件（`reference.png` / `.jpg`） |
| `model` | `model.modelName` |
| `prompt` | `config.prompt` |
| `n` | `1` |
| `size` | `resolveOpenAiPixelSize(config)` |
| `quality` | `inputValues.quality` 默认 `auto` |
| `output_format` | `inputValues.output_format` 默认 `png` |
| `background` | `auto` |
| `moderation` | `resolveModeration()` 默认 `auto` |

`Content-Type`：由 `form-data` + `form.getHeaders()` 自动带 boundary，**不**手写 boundary。

---

## 6. 文生图 / 图生图分流

```mermaid
flowchart TD
  A[imageRequest] --> B{kling?}
  B -->|yes| K[Kling]
  B -->|no| C{custom?}
  C -->|yes| G[generations]
  C -->|no| D{usesChatImageEndpoint?}
  D -->|yes| CH[chat/completions]
  D -->|no| E{gpt-image + refCount>0?}
  E -->|yes| ED[/images/edits multipart]
  E -->|no| GEN[/images/generations JSON]
```

---

## 7. 错误分类（无静默 fallback）

| HTTP | 行为 |
|------|------|
| 404 / 405 | 明确报错：上游不支持 `/images/edits`，**不**回退 generations |
| 401 | 保留上游文案 + edits 权限/分组提示 |
| 429 / 503 | 标记上游拥堵，非 Toonflow 代码问题 |
| 2xx 无图片字段 | `上游 edits 请求完成，但响应中未发现图片字段` |
| 参考图 &lt; 64B | 拒绝发送，避免 0 字节 |
| 成功但 &lt; 1024B | `上游返回图片过小`，拒绝当作成功 |

---

## 8. 诊断日志

成功请求：

```text
[third_party_image_api] openai_images EDITS POST ... endpointUsed=/images/edits isMultipart=true hasImageFile=true referenceCount=1 referenceImageBytes=...
```

失败：

```text
[third_party_image_api] edits_upstream_error status=... endpointUsed=/images/edits upstreamRequestId=... preview=...
```

---

## 9. 验收步骤

### 命令

```powershell
cd Toonflow-app
yarn lint

powershell -NoProfile -ExecutionPolicy Bypass -File tools/dev/start-toonflow-dev.ps1 -Mode restart -Force
```

### UI

设置 → 模型服务 → **第三方图像 API** → **gpt-image-2** → 图像测试

**测试 A（文生图）**

- 模式：文生图，不上传图
- 日志：`endpointUsed=/images/generations`，`isMultipart=false`

**测试 B（图生图）**

- 模式：图生图，上传参考图
- 日志：`openai_images EDITS POST`，`endpointUsed=/images/edits`，`isMultipart=true`，`hasImageFile=true`
- 成功：返回 data URL，解码后 &gt; 1024 字节
- 失败：明确错误 + toast 带 `clientRequestId`，loading 复位

---

## 10. 回滚

```powershell
git checkout -- Toonflow-app/data/vendor/third_party_image_api.ts
git checkout -- Toonflow-app/src/utils/vm.ts
git checkout -- Toonflow-web/src/components/setting/components/vendorTest/ImageModelTest.vue
Remove-Item docs-dev/GPT_IMAGE2_I2I_EDITS_IMPLEMENT.md -ErrorAction SilentlyContinue
```

重启 `Toonflow-app` `yarn dev` 重载 vendor。

---

## 11. 相关文档

- `docs-dev/GPT_IMAGE2_I2I_PROVENANCE_TRACE.md` — 修复前假图生图诊断
- `docs-dev/GPT_IMAGE_2_MODERATION_FIX.md` — moderation=auto
- `docs-dev/GPT_IMAGE_2_PROTOCOL_REFERENCE.md` — generations 协议
- `docs-dev/IMAGE_GENERATION_ZERO_BYTE_FIX.md` — 0 字节防护（ai.ts 层）
