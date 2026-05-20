# 第三方图像 / 视频 API 配置指南（rcouyi）

## 架构（三个供应商）

| 供应商 ID | 名称 | 用途 | 协议 |
|-----------|------|------|------|
| `third_party_api` | 第三方 API | 文本 / Agent | `/v1/chat/completions` |
| `third_party_image_api` | 第三方图像 API | 出图 | `/v1/images/generations`（部分 gemini 走 chat） |
| `third_party_video_api` | 第三方视频 API | 出视频 | `/task/volces/seedance`、`/task/jimeng/*` + 轮询 `/task/{id}` |

**不要**在 `third_party_api` 里添加 image/video 模型。

## 操作步骤

### 1. 重启后端（首次）

重启 `Toonflow-app` 后 `fixDB` 会自动插入 `third_party_image_api`、`third_party_video_api` 两条供应商（若不存在）。

### 2. 配置第三方图像 API

1. 模型服务 → 左侧 **第三方图像 API** → 打开启用开关  
2. Base URL：`https://api.rcouyi.com/v1`（与文本 API 相同）  
3. API Key：与 rcouyi 控制台一致  
4. **拉取模型列表** → 勾选例如：`gpt-image-1`、`gpt-image-1.5`、`imagen-4.0-generate-preview-06-06`、`qwen-image`、`doubao-seedream-4-0-250828`  
5. 或 **手动添加** → 类型只能选 **图像模型**  
6. **图像测试** 验证  

### 3. 配置第三方视频 API

1. 模型服务 → **第三方视频 API** → 启用  
2. 同样 Base URL / Key  
3. 拉取或手动添加，例如：  
   - Seedance：`doubao-seedance-1-0-pro-250528`  
   - 即梦：任意名称（默认走 `/task/jimeng/text2video` 或 `image2video`）  
4. **视频测试** 验证  

### 4. 项目 / 出图使用

- 新建项目 · 图片模型：`third_party_image_api:gpt-image-1`  
- 新建项目 · 视频模型：`third_party_video_api:doubao-seedance-1-0-pro-250528`  
- Agent 配置：仍用 `third_party_api:gpt-5.5` 等 **文本** 模型  

## 图像协议摘要

`POST {baseUrl}/images/generations`

```json
{
  "model": "gpt-image-1",
  "prompt": "...",
  "n": 1,
  "size": "1024x1024"
}
```

响应 `data[0].b64_json` 或 `data[0].url` → 经 `ai.ts` 校验后落盘。

`gemini-*-image*`、`nano-banana` 走 `POST /v1/chat/completions`，从 `message.content` 解析 `image_url`。

## 视频协议摘要

- **Seedance**：`POST {host}/task/volces/seedance` → `id` → `GET {host}/task/{id}` → `video_url`  
- **即梦**：`POST {host}/task/jimeng/text2video` 或 `image2video` → `task_id` → 同上轮询  

`host` = Base URL 去掉末尾 `/v1`（例如 `https://api.rcouyi.com`）。

## 回滚

```powershell
git checkout -- Toonflow-app/data/vendor/third_party_image_api.ts
git checkout -- Toonflow-app/data/vendor/third_party_video_api.ts
git checkout -- Toonflow-app/src/utils/vendorModelStore.ts
git checkout -- Toonflow-app/src/utils/vendorCapabilities.ts
git checkout -- Toonflow-app/src/lib/fixDB.ts
```
