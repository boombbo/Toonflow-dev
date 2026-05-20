# gpt-image-2 moderation 最小修复（P1-GPT-IMAGE2-MODERATION-FIX）

> **任务编号**：P1-GPT-IMAGE2-MODERATION-FIX  
> **类型**：backend_vendor_patch + docs  
> **日期**：2026-05-20  
> **依据**：`docs-dev/GPT_IMAGE_2_PROTOCOL_REFERENCE.md`

---

## 1. 为什么先不做 image2 专线

- snapai 与 Toonflow **共用同一路径** `POST /v1/images/generations`，无需为 `gpt-image-2` 单独换 path 或新建 `openai_image2_api` vendor。
- 协议对比显示 **最关键差异仅 `moderation` 字段**；`background` 两边默认均为 `auto`，`model` 直传 DB 名即可。
- 401 / `invalid_api_key` 更可能来自 **rcouyi 分组权限或上游 Key 路由**，而非缺少整条专线；应先补 body 再 Apifox diff，避免过度重构。

---

## 2. snapai 与 Toonflow body 差异（修复前 / 后）

| 字段 | snapai（gpt-image-2 成功体） | Toonflow 修复前 | Toonflow 修复后 |
|------|------------------------------|-----------------|-----------------|
| path | `/v1/images/generations` | 同左 | 同左 |
| `model` | `gpt-image-2` | `model.modelName` | 不变 |
| `moderation` | **`auto`** | **未发送** | **`auto`（可配置 `low`）** |
| `background` | `auto` | `auto` | `auto` |
| `quality` | `auto` | `auto` | `auto` |
| `output_format` | `png` | `png` | `png` |
| `size` | `1024x1024` | 可配置 | 可配置 |

snapai 等价 curl（rcouyi）：

```bash
curl -sS -X POST 'https://api.rcouyi.com/v1/images/generations' \
  -H 'Authorization: Bearer sk-YOUR_KEY' \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "gpt-image-2",
    "prompt": "a simple red apple on white background",
    "n": 1,
    "size": "1024x1024",
    "quality": "auto",
    "background": "auto",
    "output_format": "png",
    "moderation": "auto"
  }'
```

---

## 3. 本次只补 moderation 的原因

1. **协议文档 Q11** 将 `moderation` 列为对 gpt-image-2 影响最大的 body 差异。
2. **inputValues 无法绕过**：旧 vendor 代码未读取 `moderation`，仅改 UI 配置无效。
3. **最小侵入**：只改 `third_party_image_api.ts` 的 `imageRequestViaGenerations` body + 可选 input；**未改** `ai.ts`、Agent、DB schema。
4. **兼容 gpt-image-1 / 1.5**：同一 generations 路径，多传 `moderation: auto` 与 snapai 行为一致。

### 代码要点

- `moderation: resolveModeration()`，`resolveModeration()` 仅允许 `auto` | `low`，非法值回退 `auto`。
- 默认 `inputValues.moderation = "auto"`。
- 日志：`moderation=${body.moderation}` 便于对照 Apifox。
- gpt-image-2 若仍 401，错误文案提示 rcouyi 分组与 raw body diff（不吞错）。

---

## 4. 修改文件

| 文件 | 变更 |
|------|------|
| `Toonflow-app/data/vendor/third_party_image_api.ts` | body 增加 `moderation`；input `moderation`；401 提示 |
| `Toonflow-web/src/components/setting/components/vendorConfig.vue` | moderation 说明 + 下拉（auto/low） |
| `docs-dev/GPT_IMAGE_2_MODERATION_FIX.md` | 本文档 |
| `.toonflow-dev/gpt-image-2-test-run.mjs` | 验收 runner（非业务代码） |

**未修改**：`ai.ts`、`productionAgent`、`scriptAgent`、DB schema、`package.json`、`yarn.lock`。

---

## 5. 验收配置

| 项 | 值 |
|----|-----|
| 供应商 | `third_party_image_api` |
| baseUrl | `https://api.rcouyi.com/v1` |
| providerMode | `openai_images` |
| submitPath | `/images/generations` |
| model | `gpt-image-2` |
| defaultSize / openAiSize | `1024x1024` |
| quality | `auto` |
| output_format | `png` |
| moderation | `auto` |

验收命令（后端 `:10588` 已启动）：

```powershell
cd d:\ComfyUIApi\16宫格分镜_\BBBBBBBBBBBB
node .toonflow-dev/gpt-image-2-test-run.mjs
```

---

## 6. 测试结果

**验收时间**：2026-05-20（`node .toonflow-dev/gpt-image-2-test-run.mjs`，后端已重启）

| 指标 | 结果 |
|------|------|
| imageTest HTTP | **502**（body `code: 400`） |
| 业务 msg | `图像生成失败 HTTP 401` + `invalid_api_key` |
| 上游 message | `Incorrect API key provided: sk-svcac...`（rcouyi 上游 Key，非用户 sk-D...） |
| 错误文案是否含 moderation 提示 | **是** —「当前请求已补齐 moderation=auto…」 |
| 是否返回图片（本次） | **否** |
| testImage.jpg 字节 | 1,717,140（**历史成功残留 PNG**，本次未更新） |
| 是否新增 0 字节文件 | **否** |
| 后端日志 | `moderation=auto` 已发送 |

**结论**：Toonflow 请求体已对齐 snapai 的 `moderation: auto`；本次失败为 **rcouyi 对 gpt-image-2 的 401 上游鉴权**，需 Apifox raw body diff 或开通分组。同环境历史曾 200 成功出图（~608KB，~263s）。

---

## 7. 若仍 401：下一步

1. Apifox 抓 **成功** 的 gpt-image-2 请求 raw body。
2. 对照 Toonflow 后端日志行：`openai_images POST ... moderation=auto`。
3. 逐字段 diff（`moderation`、`background`、`output_format`、`size`）。
4. 确认 rcouyi 控制台 **分组已开通 gpt-image-2**（1.5 能通不代表 2 同权）。
5. **不要**在本轮新增 image2 专线或改 path；若 body 完全一致仍 401，联系 rcouyi 查上游 Key。

---

## 8. 回滚

```powershell
git checkout -- Toonflow-app/data/vendor/third_party_image_api.ts
git checkout -- Toonflow-web/src/components/setting/components/vendorConfig.vue
Remove-Item docs-dev/GPT_IMAGE_2_MODERATION_FIX.md -ErrorAction SilentlyContinue
```

重启 `yarn dev`（Toonflow-app）使 vendor 模板重载。

---

## 9. moderation 最终默认值

**`auto`**（`inputValues.moderation` 为空或非法时同为 `auto`）。
