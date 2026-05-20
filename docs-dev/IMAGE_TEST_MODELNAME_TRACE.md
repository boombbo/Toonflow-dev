# 图像测试 modelName 全链路追踪（P1-IMAGE-TEST-MODELNAME-TRACE）

> **任务编号**：P1-IMAGE-TEST-MODELNAME-TRACE  
> **类型**：diagnostics + frontend_ui + docs  
> **日期**：2026-05-20

---

## 1. 现象

- 弹窗标题：`图像生成测试 - gpt-image-2`
- 上游错误偶现：`上游模型 gpt-image-1 负载已饱和` / `No available channel for model gpt-image-1`
- 用户侧 **gpt-image-2 文生图曾成功返回图片**（链路已打通）

---

## 2. 代码审查结论（静态）

| 环节 | modelName 来源 | 是否改写为 gpt-image-1 |
|------|----------------|------------------------|
| `ImageModelTest.vue` payload | `props.modelName` | **否** |
| `imageTest.ts` | `req.body.modelName` → `u.Ai.Image(\`${id}:${modelName}\`)` | **否** |
| `third_party_image_api.ts` body | `model: model.modelName`（DB 名直传） | **否** |

**结论**：Toonflow 全链路 **未发现** `gpt-image-2` → `gpt-image-1` 的代码别名。若 Payload 为 `gpt-image-2` 而错误提 `gpt-image-1`，优先归类为：

1. **rcouyi 上游路由/分组**（2 走 1 的通道或配额文案）
2. **旧请求 toast 污染**（连续点多模型测试）
3. **429/503 拥堵**（非 size/moderation 问题）

---

## 3. 本次诊断增强

### 前端 `ImageModelTest.vue`

- `clientRequestId` + `activeClientRequestId`：仅最新请求更新 UI
- `inFlight`：进行中禁止重复点击
- `loading` / `finally`：保证结束转圈
- 控制台 `[ImageModelTest]`：`request_start` / `success` / `error` / `stale_*_ignored`
- 上游错误模型名与请求不一致时，追加提示文案

### 后端 `imageTest.ts`

- 控制台 `[imageTest][start|success|error]`：vendorId、modelName、openAiSize、providerMode、moderation、durationMs（**不含 apiKey**）

### Vendor `third_party_image_api.ts`

- 请求日志：`model.modelName` + `body.model`
- 失败日志：`upstreamModelsMentioned`（从错误文案正则提取 `gpt-image-*`）

---

## 4. 如何核对（手工）

1. 打开 DevTools → Network → `imageTest`
2. 看 Request Payload：

```json
{
  "id": "third_party_image_api",
  "modelName": "gpt-image-2",
  "openAiSize": "1024x1024",
  "clientRequestId": "..."
}
```

3. 后端日志应出现：

```text
[imageTest][start] {"modelName":"gpt-image-2","requestBodyModel":"gpt-image-2",...}
[third_party_image_api] openai_images POST ... model.modelName=gpt-image-2 body.model=gpt-image-2
```

4. 若失败且 `upstreamModelsMentioned=gpt-image-1` 而 body 为 `gpt-image-2` → **标记为 rcouyi 上游路由/通道问题**

---

## 5. 错误分类建议

| 错误 | 类型 | 处理 |
|------|------|------|
| 429 load saturated | 临时拥堵 | 稍后重试 |
| 503 no available channel | 无可用通道 | 换分组 / 重试 |
| 401 invalid_api_key | Key/权限 | 查 rcouyi 分组 |
| 400 size_not_supported | 参数 | 改 1024x1024 |

---

## 6. 验收清单

| # | 项 | 状态 |
|---|-----|------|
| 1 | gpt-image-2 测试时前端/后端/vendor modelName 日志一致 | 待 UI 实测 |
| 2 | 上游仍报 gpt-image-1 时文档标记为 rcouyi 问题 | ✅ 本文 §2 |
| 3 | loading 不无限转圈 | ✅ finally + inFlight |
| 4 | 失败不覆盖成功结果 | ✅ stale_*_ignored |
| 5 | lint | 见变更报告 |

---

## 7. 修改文件

| 文件 | 变更 |
|------|------|
| `Toonflow-web/.../ImageModelTest.vue` | clientRequestId、防重复、错位提示 |
| `Toonflow-app/.../imageTest.ts` | 诊断日志 |
| `Toonflow-app/data/vendor/third_party_image_api.ts` | upstream 模型名提取日志 |
| `docs-dev/IMAGE_TEST_MODELNAME_TRACE.md` | 本文档 |

**未改**：`ai.ts`、DB schema、package.json、Agent 主流程。

---

## 8. 回滚

```powershell
git checkout -- Toonflow-web/src/components/setting/components/vendorTest/ImageModelTest.vue
git checkout -- Toonflow-app/src/routes/setting/vendorConfig/modelTest/imageTest.ts
git checkout -- Toonflow-app/data/vendor/third_party_image_api.ts
Remove-Item docs-dev/IMAGE_TEST_MODELNAME_TRACE.md -ErrorAction SilentlyContinue
```
