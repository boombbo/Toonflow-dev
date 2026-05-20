# 图片生成 0 字节问题修复说明

> **日期**：2026-05-20  
> **根因**：供应商 `imageRequest` 返回空字符串 / 非图片内容时，`AiImage.save()` 曾直接 `u.oss.writeFile`，写出 0 字节文件；`getImage` 仍可能显示「已完成」。

## 根因确认

```text
供应商空返回 → ai.ts 未校验 → writeFile 写出 0 字节 → getImage 曾返回已完成 → 前端破图
```

## 修复层

| 层级 | 文件 | 措施 |
|------|------|------|
| 核心 | `Toonflow-app/src/utils/ai.ts` | `run()` 后 `resolveImageResult`；`save()` 仅写入通过 magic 校验的 Buffer |
| 下载 | `normalizeGeneratedImage.ts` + `ai.ts` `urlToBase64` | URL 下载校验 content-type / 空 buffer / 图片 magic |
| 资产生成 | `generateAssets.ts` + `saveValidatedAssetImage.ts` | 临时文件 → `commitTempAiImageSave` 二次校验 |
| 列表 | `getImage.ts` | 0 字节 / 过小 / magic 失败 → `生成失败` |
| 前端 | `generateImage.vue` | `request-method` 替代 `action=""`；失败展示 `errorReason` |
| 模型 | `third_party_api.ts` | `imageRequest` 抛错，不返回 `""` |
| 下拉 | `modelSelect/getModelList.ts` | `third_party_api` 不出现在 `type=image` 列表 |

## 诊断：查找 0 字节图片（只读，不自动删除）

```powershell
Get-ChildItem -Recurse "D:\ComfyUIApi\16宫格分镜_\BBBBBBBBBBBB\Toonflow-app" -Include *.jpg,*.jpeg,*.png,*.webp -ErrorAction SilentlyContinue |
  Where-Object { $_.Length -eq 0 } |
  Select-Object FullName, Length, LastWriteTime
```

**2026-05-20 扫描结果**：当前仓库内 **4** 个 0 字节文件（均为历史遗留，位于 `data/oss/.../role/*.jpg` 与 `data/oss/testImage.jpg`）。修复后新生成路径不应再产生 0 字节文件；历史文件需手工决定是否删除。

## 验证步骤

1. `powershell -NoProfile -ExecutionPolicy Bypass -File tools/dev/start-toonflow-dev.ps1 -Mode reuse`
2. 新建剧情 → 新建角色 → 生成图片（选择**真实 image 模型**，非 third_party_api）
3. 成功：ETag 非 `W/"0-..."`，文件 size ≥ 1024
4. 失败：卡片「生成失败」+ `errorReason`，磁盘无新 0 字节 jpg

## 回滚

```powershell
git checkout -- Toonflow-app/src/utils/ai.ts
git checkout -- Toonflow-app/data/vendor/third_party_api.ts
git checkout -- Toonflow-app/src/routes/modelSelect/getModelList.ts
Remove-Item -Force docs-dev\IMAGE_GENERATION_ZERO_BYTE_FIX.md
```

（若已存在 `normalizeGeneratedImage.ts` / `saveValidatedAssetImage.ts` / `getImage.ts` / `generateImage.vue` 的早期修复，回滚时一并还原。）
