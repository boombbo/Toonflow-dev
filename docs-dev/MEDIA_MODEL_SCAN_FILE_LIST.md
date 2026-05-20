# MEDIA_MODEL 扫描覆盖清单

> 任务 P0-MEDIA-ROUTE-SCAN · 只读扫描 · 2026-05-20

## 统计

| 类别 | 数量 | 要求 |
|------|------|------|
| Toonflow-app/src/**/*.ts | 222 | ≥80 |
| Toonflow-web/src/**/*.vue | 86 | ≥30 |
| Toonflow-web/src/**/*.ts | 42 | ≥20 |
| Toonflow-app/data/vendor/*.ts | 13 | 全部 |

## data/vendor（13，全部已读）

- `Toonflow-app/data/vendor/third_party_api.ts`
- `Toonflow-app/data/vendor/third_party_image_api.ts`
- `Toonflow-app/data/vendor/third_party_video_api.ts`
- `Toonflow-app/data/vendor/openai.ts`
- `Toonflow-app/data/vendor/deepseek.ts`
- `Toonflow-app/data/vendor/klingai.ts`
- `Toonflow-app/data/vendor/volcengine.ts`
- `Toonflow-app/data/vendor/vidu.ts`
- `Toonflow-app/data/vendor/toonflow.ts`
- `Toonflow-app/data/vendor/minimax.ts`
- `Toonflow-app/data/vendor/atlascloud.ts`
- `Toonflow-app/data/vendor/grsai.ts`
- `Toonflow-app/data/vendor/null.ts`

## 图像/视频主链路（已精读）

### 后端

- `Toonflow-app/src/utils/ai.ts` — `getVendorTemplateFn`, `AiImage`, `AiVideo`
- `Toonflow-app/src/utils/vendor.ts` — `getModelList` 合并模板+DB
- `Toonflow-app/src/utils/vendorCapabilities.ts` — 能力矩阵
- `Toonflow-app/src/utils/vendorModelStore.ts` — 导入/清空
- `Toonflow-app/src/utils/guessModelType.ts` — 远程模型类型猜测
- `Toonflow-app/src/utils/modelTestHttp.ts` — 测试接口 HTTP 状态分类
- `Toonflow-app/src/routes/modelSelect/getModelList.ts`
- `Toonflow-app/src/routes/setting/vendorConfig/*`（含 modelTest）
- `Toonflow-app/src/routes/assetsGenerate/generateAssets.ts`
- `Toonflow-app/src/routes/production/**/generate*.ts`

### 前端

- `Toonflow-web/src/components/setting/components/vendorConfig.vue`
- `Toonflow-web/src/components/setting/components/vendorTest/ImageModelTest.vue`
- `Toonflow-web/src/components/setting/components/vendorTest/VideoModelTest.vue`
- `Toonflow-web/src/components/modelSelect.vue`
- `Toonflow-web/src/views/project/components/projectDialog.vue`
- `Toonflow-web/src/views/assets/components/generateImage.vue`

## 未读（仅列路径）

- `Toonflow-app/data/serve/app.js` — **构建产物，禁止读取**（约 259k 行）

## 完整后端 .ts 列表

见同目录 `_scan_backend_ts_list.txt`（222 条）。
