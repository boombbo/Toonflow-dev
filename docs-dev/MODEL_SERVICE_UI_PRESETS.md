# 模型服务 UI 快捷预设（仅前端）

## 范围

- 仅修改 `Toonflow-web/src/components/setting/components/vendorConfig.vue`
- 不新增 vendorId；第三方与本地均复用 **`openai`（OpenAI标准接口）**

## 入口

| 入口 | 行为摘要 |
|------|----------|
| 配置第三方 API | 切到 `openai`；不覆盖已有 apiKey / 非默认 baseUrl；默认 baseUrl 时在提示中列出示例 |
| 配置本地模型 | 切到 `openai`；空或默认 baseUrl → `http://localhost:11434/v1`；空 apiKey → `ollama`；有变更时调用既有 `updateVendorInputs` |

## Base URL 示例（第三方提示）

- `https://api.deepseek.com/v1`
- `https://api.openai.com/v1`
- `https://dashscope.aliyuncs.com/compatible-mode/v1`
- `https://api.siliconflow.cn/v1`
- `https://openrouter.ai/api/v1`

## 本地占位

- Base URL：`http://localhost:11434/v1`（仅当空或仍为 `https://api.openai.com/v1`）
- API Key：`ollama`（仅当 apiKey 为空）

## 启用

若 `openai` 未启用，尝试 `POST /setting/vendorConfig/enableVendor`（与左侧开关相同）；失败则提示用户手动打开开关。

## 验证

```powershell
cd D:\ComfyUIApi\16宫格分镜_\BBBBBBBBBBBB\Toonflow-web
corepack yarn dev
```

浏览器：`http://localhost:50188` → 设置 → 模型服务。

## 回滚

还原 `vendorConfig.vue`（及可选删除本文档）即可。
