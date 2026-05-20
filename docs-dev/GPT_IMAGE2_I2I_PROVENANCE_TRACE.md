# gpt-image-2 图生图全链路溯源（P1-GPT-IMAGE2-I2I-PROVENANCE-TRACE）

> **任务编号**：P1-GPT-IMAGE2-I2I-PROVENANCE-TRACE  
> **类型**：diagnostics + minimal_ui_debug + docs  
> **日期**：2026-05-20  
> **约束**：未改 `ai.ts`、DB schema、`package.json`；未删除/替换模型。

---

## 1. 任务结论（一句话）

**当前 Toonflow「图像生成测试 → gpt-image-2 → 图生图」会把参考图传到后端并进入 `referenceList`，但 vendor 层 `imageRequestViaGenerations` 仍只 POST `/images/generations` 的 JSON body（无 `image` 字段），参考图未进入 rcouyi 上游 —— 实为「带参考图的文生图」。**

**判定：结论 A**（见 §6）。

---

## 2. 全链路记录字段（日志键名，不泄露 Key）

### 2.1 前端 `ImageModelTest.vue`

控制台前缀：`[ImageModelTest][request_start]` / `request_success` / `request_error` / `stale_*_ignored`

| 字段 | 说明 |
|------|------|
| `activeTab` | `text2image` / `image2image` / `multiReference`（由 `testMode` 映射） |
| `dialogTitleModelName` | 弹窗标题中的模型名（`props.modelName`） |
| `requestBodyId` | 供应商 id（如 `third_party_image_api`） |
| `requestBodyModelName` | POST body `modelName` |
| `requestBodyOpenAiSize` | 可选 `openAiSize`（1024x1024 等） |
| `promptPreview` | prompt 前 120 字 |
| `hasUploadedImage` | 是否选了本地图 |
| `uploadFieldName` | 图生图时为 **`imageBase64`** |
| `uploadImageBytes` | 原始文件 `File.size`（字节） |
| `sendsImageBase64` | 是否把 data URL 写入 `imageBase64` |
| `sendsFilePath` / `sendsImageUrl` | 恒为 **false**（测试页不传路径/URL） |
| `clientRequestId` | 每次点击「开始测试」新生成 UUID |

**Network Request Payload（DevTools）** 与上表一致：`modelName`、`id`、`prompt`、`clientRequestId`、`testMode`；图生图额外 **`imageBase64`**（`data:image/...;base64,...`）。

### 2.2 后端 `imageTest.ts`

控制台前缀：`[imageTest][start]` / `success` / `error`

| 字段 | 说明 |
|------|------|
| `vendorId` | 同前端 `id` |
| `modelName` | 直传，**未发现** 改写为 `gpt-image-1` |
| `openAiSize` | 测试覆盖尺寸 |
| `promptPreview` | 前 120 字 |
| `hasImageBase64` / `hasReferenceImage` | 是否收到参考图 |
| `referenceImageBytes` | 由 base64 估算的字节数 |
| `uploadFieldName` | 有图时为 `imageBase64` |
| `providerMode` | 供应商 `inputValues.providerMode`（默认 `openai_images`） |
| `endpointUsed`（start） | 说明由 vendor 决定 |
| `requestBodyModel` | 等于 `modelName` |
| `requestBodySize` / `requestBodyModeration` | 来自供应商配置 |
| `requestBodyHasImageField` | **false**（imageTest 不直接拼 OpenAI body） |
| `requestContentType` | `application/json` |
| `isMultipart` | **false** |
| `clientRequestId` | 与前端一致 |

收到 `imageBase64` 后构造：

```ts
referenceList = [{ type: "image", base64: imageBase64 }]
```

再调用 `u.Ai.Image(\`${id}:${modelName}\`).run({ prompt, referenceList, ... })`（**未改 `ai.ts`**，仅经既有 Image 入口进入 vendor）。

### 2.3 Vendor `third_party_image_api.ts`

控制台前缀：`[third_party_image_api] i2i_provenance` / `openai_images POST` / `upstream_error`

| 字段 | 说明 |
|------|------|
| `endpointUsed` | 如 **`/images/generations`**（`submitPath` 可配，默认此路径） |
| `POST` URL | `{baseURL}{submitPath}` — 日志中域名可打码，保留 path + query 无 |
| `contentType` | `application/json` |
| `isMultipart` | **false** |
| `model.modelName` / `body.model` | 均为所选模型（如 `gpt-image-2`） |
| `referenceCount` | `referenceList.length` |
| `referenceImageBytes≈` | 估算值 |
| `hasImageInBody` | **`bodyHasImageLikeField(body)` → 对 generations 恒 false** |
| `bodyKeys` | 典型：`model,prompt,n,size,quality,output_format,background,moderation` |
| `upstreamModelsMentioned` | 从错误 JSON 正则提取 `gpt-image-*` |
| `upstreamRequestId` | 若响应含 `request_id` |

**gpt-image-2 路由**：`usesChatImageEndpoint()` **不包含** gpt-image-2 → 走 **`openai_images` → `imageRequestViaGenerations`**，**不走** `/chat/completions`。

---

## 3. 九项验收对照表

| # | 文档要求 | 现状 |
|---|----------|------|
| 1 | 前端显示模型名 | 弹窗 header：`图像生成测试 - {modelName}`；日志 `dialogTitleModelName` |
| 2 | Network Payload `modelName` | 与弹窗一致，直传后端 |
| 3 | 后端收到 `modelName` | `[imageTest][start].modelName` 一致 |
| 4 | vendor `body.model` | `[third_party_image_api] body.model=` 与 `model.modelName` 一致 |
| 5 | `endpointUsed` | `/images/generations`（默认） |
| 6 | 是否真实携带参考图到**上游** | **否**（`hasImageInBody=false`，仅有 `referenceCount>0` 警告日志） |
| 7 | 是否 multipart | **否** |
| 8 | 上游错误里的模型名 | `upstreamModelsMentioned`；若 Payload 为 gpt-image-2 而错误提 gpt-image-1 → **结论 D**（rcouyi 路由/分组/别名或旧 toast） |
| 9 | 结果为何不像 image2 | 见 §5 |
| 10 | 下一步修哪一层 | 见 §7 |

---

## 4. 图生图是否真实生效 — 四种判定

### 结论 A（当前 gpt-image-2 图生图）✅

- `endpointUsed = /images/generations`
- `requestBody` / vendor `body` **无** `image` / `input_image` / `images`
- `hasReferenceImage=true` 仅表示**后端收到了** base64，**不代表上游收到**

**结论：当前所谓图生图对 gpt-image-2 实际是文生图，参考图未进入上游。**

### 结论 B — 不适用

未把图片塞进 prompt 或额外 base64 字段（generations body 仅标准字段）。

### 结论 C — 不适用（gpt-image-2）

`/images/edits` 与 Responses image input **未实现**；chat 路由仅 gemini 等（`usesChatImageEndpoint`）。

### 结论 D — 间歇出现

若 DevTools Payload `modelName=gpt-image-2`，日志 `body.model=gpt-image-2`，但上游 401/503 文案含 `gpt-image-1` → **rcouyi 上游路由/分组/别名**，非 Toonflow 改写。

---

## 5. 当前生成结果为什么不像「image2 图生图」

1. **参考图未参与生成**：上游只收到 `prompt`，模型按纯文生图理解，无法保持构图/人物/风格。
2. **文生图已打通时的差异**：同 prompt 下 t2i 与「伪 i2i」输出可能相近，用户会误以为参考图生效。
3. **429/503/401**：通道拥堵或 Key/分组问题，与 i2i 无关；错误里偶发 `gpt-image-1` 加重困惑（见结论 D）。
4. **耗时**：gpt-image-2 文生图可达数分钟，与 i2i 无关。

---

## 6. UI 修复（第三部分，已实现）

文件：`Toonflow-web/src/components/setting/components/vendorTest/ImageModelTest.vue`

| 项 | 实现 |
|----|------|
| 每次测试 `clientRequestId` | `crypto.randomUUID()` 或 fallback |
| loading 时禁用开始测试 | `canSubmit` 在 `loading \|\| inFlight` 时为 false；按钮 `:disabled="!canSubmit"` |
| `finally` 复位 loading | 仅当 `activeClientRequestId === clientRequestId` 时 `loading=false` |
| 旧请求不覆盖新状态 | `stale_success_ignored` / `stale_error_ignored` |
| 错误 toast | `[clientRequestId] [modelName] msg`；图生图附加 i2i_provenance 提示 |

---

## 7. 下一步应修哪一层（禁止改 ai.ts 的前提下）

| 层级 | 建议 | 说明 |
|------|------|------|
| **优先：vendor** `third_party_image_api.ts` | `referenceList.length > 0` 且 `openai_images` 时改走 **`POST /images/edits`**（multipart：`image` + `prompt` + `model` + `size`…）或供应商文档规定的 image 字段 | **不经过 ai.ts 主流程变更**；仅扩展 vendor `imageRequest` |
| **次选：imageTest 诊断** | 保持 `hasReferenceImage` / `endpointUsed` 日志 | 已完成 |
| **前端** | 图生图模式增加说明：「gpt-image-2 当前参考图仅到后端，未发上游」 | 可选 copy，非必须 |
| **不建议** | 把 base64 拼进 `prompt` | 结论 B，不稳定 |
| **不改** | `ai.ts`、DB、package.json、模型列表替换 | 任务禁止 |

**generations vs edits vs responses**：

- **文生图**：继续 `/images/generations` + `moderation=auto`（见 `GPT_IMAGE_2_MODERATION_FIX.md`）。
- **图生图（gpt-image-2）**：应在 **vendor 层** 增加 **`/images/edits`**（或 rcouyi 文档等价 multipart），**不要**继续仅用 generations。
- **Responses API image input**：若 rcouyi 后续只支持该路径，再在 vendor 增加第三路由；当前代码未实现。

---

## 8. 手工验证步骤

1. 启动：`Toonflow-app` `yarn dev`（10588）、`Toonflow-web` `yarn dev`（50188）。
2. 设置 → 供应商 → **第三方图像 API** → 模型 **gpt-image-2** → 图像测试。
3. 选 **图生图**，上传一张明显风格的图，填 prompt，点「开始测试」。
4. 浏览器控制台：`[ImageModelTest][request_start]` → 确认 `activeTab=image2image`、`sendsImageBase64=true`。
5. 后端终端：`[imageTest][start]` → `hasReferenceImage=true`、`referenceImageBytes>0`。
6. 后端终端：`[third_party_image_api] i2i_provenance route=generations` → `hasImageInBody=false` → **结论 A**。
7. 连续点两次测试：确认第二次不会被第一次 toast 覆盖（`clientRequestId` 不同；旧请求 `stale_*_ignored`）。

---

## 9. 修改文件与回滚

### 修改文件

| 文件 | 变更 |
|------|------|
| `Toonflow-web/.../vendorTest/ImageModelTest.vue` | clientRequestId、防 stale、loading/finally、i2i 诊断日志 |
| `Toonflow-app/.../modelTest/imageTest.ts` | 全链路诊断字段 |
| `Toonflow-app/data/vendor/third_party_image_api.ts` | `i2i_provenance` 日志（只读诊断，未改请求体行为） |
| `docs-dev/GPT_IMAGE2_I2I_PROVENANCE_TRACE.md` | 本文档 |

### 未修改

- `Toonflow-app/src/utils/ai.ts`
- DB schema、`package.json`、`yarn.lock`

### 回滚

```powershell
git checkout -- Toonflow-web/src/components/setting/components/vendorTest/ImageModelTest.vue
git checkout -- Toonflow-app/src/routes/setting/vendorConfig/modelTest/imageTest.ts
git checkout -- Toonflow-app/data/vendor/third_party_image_api.ts
Remove-Item docs-dev/GPT_IMAGE2_I2I_PROVENANCE_TRACE.md -ErrorAction SilentlyContinue
```

重启 `Toonflow-app` `yarn dev` 以重载 vendor 模板。

### 验证命令

```powershell
cd Toonflow-app; yarn lint
```

---

## 10. 相关文档

- `docs-dev/GPT_IMAGE_2_PROTOCOL_REFERENCE.md` — generations 协议与 snapai 对比  
- `docs-dev/GPT_IMAGE_2_MODERATION_FIX.md` — moderation=auto  
- `docs-dev/IMAGE_TEST_MODELNAME_TRACE.md` — modelName 与上游 gpt-image-1 错位  

---

## 11. 验收清单（任务原文）

- [x] 图生图测试可看到 `hasReferenceImage=true/false`（后端 `[imageTest]`）
- [x] 可看到 `endpointUsed`（vendor `i2i_provenance` / `openai_images POST`）
- [x] 可看到 `final body.model`（vendor 日志 `body.model`）
- [x] loading 不再无限转（finally + stale 忽略）
- [x] 未修改 `ai.ts`
- [x] `Toonflow-app` `yarn lint` 通过
