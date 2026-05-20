# gpt-image-2 HTTP 协议参考（snapai vs Toonflow）

> **任务编号**：P1-GPT-IMAGE-2-PROTOCOL-EXTRACTION  
> **类型**：readonly_scan + docs_only  
> **日期**：2026-05-20  
> **背景**：同一 rcouyi Key 在 Cherry Studio / Apifox / snapai 可调通 `gpt-image-2`；Toonflow `third_party_image_api` 测 `gpt-image-2` 报 **HTTP 401 invalid_api_key**，而 `gpt-image-1.5` 可通。

---

## 1. 引用来源声明

| 项目 | 路径 | License |
|------|------|---------|
| **snapai** | `user/snapai/`（MIT CLI，OpenAI Images API 参考实现） | [MIT License](../user/snapai/LICENSE) — Copyright (c) 2025 Code with Beto LLC |
| **Toonflow** | `Toonflow-app/data/vendor/third_party_image_api.ts` 等 | 本项目自有代码 |

**声明**：本文档仅提取 HTTP 协议事实用于对比诊断。**不允许**将 snapai 源码复制进 Toonflow 业务代码。

---

## 2. 已扫描文件

| # | 路径 | 状态 |
|---|------|------|
| 1 | `user/snapai/src/services/openai.ts` | ✅ 已读 |
| 2 | `user/snapai/src/commands/icon.ts` | ✅ 已读 |
| 3 | `user/snapai/src/types.ts` | ✅ 已读 |
| 4 | `user/snapai/package.json` | ✅ 已读 |
| 5 | `Toonflow-app/data/vendor/third_party_image_api.ts` | ✅ 已读 |
| 6 | `Toonflow-app/src/routes/setting/vendorConfig/modelTest/imageTest.ts` | ✅ 已读 |

**是否找到 gpt-image-2 具体调用代码**：✅ 是 — `openai.ts` 中 `OPENAI_IMAGE_MODEL_ID_BY_ALIAS["gpt-image-2"]` → `client.images.generate()`（`openai.ts:14-18`, `83`）。

**未安装依赖**：未读取 `node_modules/openai`；SDK 底层 URL/headers 依据 snapai 源码 + OpenAI SDK 公开约定推断。

---

## 3. 十二问（每项带 文件:行号）

### snapai 协议事实

#### Q01 — HTTP method 与完整 URL path

| 项 | 答案 |
|----|------|
| Method | **POST**（OpenAI SDK `images.generate`） |
| Path | **`/v1/images/generations`** |
| 完整 URL | 默认 `https://api.openai.com/v1/images/generations`；对接 rcouyi 时由环境变量 **`OPENAI_BASE_URL`**（SDK 标准）覆盖为 `https://api.rcouyi.com/v1/images/generations` |

**依据**：

- snapai **未在代码内**写 baseURL（`openai.ts:35-37` 仅 `new OpenAI({ apiKey })`）
- 调用入口：`client.images.generate(requestParams)`（`openai.ts:83`）
- OpenAI SDK v4 固定 resource 为 `images/generations`；snapai `package.json:53` 依赖 `"openai": "^4.20.1"`
- README 明确 gpt-image-2 与 gpt-1.5 **同一路径**（`README.md:77`, `147-157`）

#### Q02 — 请求 headers 完整列表

snapai **不显式构造 headers**，由 OpenAI SDK 注入。等价 HTTP 层至少包含：

| Header | 值 |
|--------|-----|
| `Authorization` | `Bearer <apiKey>` |
| `Content-Type` | `application/json` |

**依据**：`openai.ts:35-37`（SDK 客户端）；Key 来源 `SNAPAI_API_KEY` / `OPENAI_API_KEY` / config（`openai.ts:23-27`）。

#### Q03 — 请求 body 字段

构建于 `openai.ts:68-81`，经 `client.images.generate` 序列化为 JSON：

| 字段 | 类型 | 必填 | snapai 取值 / 说明 |
|------|------|------|-------------------|
| `model` | string | ✅ | CLI `--model gpt-image-2` → 解析为 **`"gpt-image-2"`**（非别名缩略）；映射表 `openai.ts:14-18`, `151-162` |
| `prompt` | string | ✅ | 用户 prompt（`openai.ts:70`） |
| `n` | number | ✅ | `numImages`，默认 1，范围 1–10（`openai.ts:71`, `117-118`） |
| `size` | string | ✅ | **固定 `"1024x1024"`**（`openai.ts:20`, `72`） |
| `quality` | string | ✅ | `auto` \| `high` \| `medium` \| `low`（`openai.ts:76-78`, `108-114`） |
| `background` | string | ✅ | `transparent` \| `opaque` \| `auto`；**gpt-image-2 禁止 `transparent`**（`openai.ts:79`, `125-128`） |
| `output_format` | string | ✅ | `png` \| `jpeg` \| `webp`（`openai.ts:80`, `130-131`） |
| `moderation` | string | ✅ | `low` \| `auto`（`openai.ts:81`, `133-134`） |
| `response_format` | — | ❌ **未设置** | snapai 代码中**无此字段** |
| `output_compression` | — | ❌ **无** | 未出现在 snapai 源码 |

#### Q04 — fetch 还是 SDK

**OpenAI 官方 SDK**（`openai` npm，`openai.ts:1`, `83`），不是手写 `fetch`。

#### Q05 — b64_json 与 url 返回分支

snapai **只处理 `b64_json`**：

```text
response.data.map → 若 !img.b64_json 则 throw（openai.ts:90-95）
```

**无** `url` 下载分支。`types.ts:24-28` 中的 `url` 类型为遗留/文档型，与当前 `generateIcon` 实现无关。

隐含：SDK 默认或模型默认使响应含 `b64_json`（snapai 未显式传 `response_format`）。

#### Q06 — gpt-image-2 vs gpt-image-1 / gpt-image-1.5 是否不同路径

**否，同一路径、同一函数** `OpenAIService.generateIcon` → `client.images.generate`（`openai.ts:40-83`）。

差异仅在：

| 差异点 | gpt-image-1 / 1.5 | gpt-image-2 |
|--------|---------------------|-------------|
| `model` 字段 | `gpt-image-1` / `gpt-image-1.5`（经别名 `gpt-1` / `gpt-1.5`） | **`gpt-image-2`** |
| `background=transparent` | 允许 | **校验拒绝**（`openai.ts:125-128`） |
| HTTP path | `/v1/images/generations` | **相同** |

---

### Toonflow 现状

#### Q07 — third_party_image_api 当前 HTTP method + URL + body

**路由**：`providerMode=openai_images` 且模型名不匹配 chat 图像规则时 → `imageRequestViaGenerations`（`third_party_image_api.ts:374-386`）。

| 项 | 值 |
|----|-----|
| Method | **POST**（`third_party_image_api.ts:300`） |
| URL | `{baseURL}{submitPath}`，默认 `https://api.rcouyi.com/v1` + `/images/generations`（`third_party_image_api.ts:287-300`, `125-127`） |
| Body | 见下表（`third_party_image_api.ts:290-298`） |

| 字段 | Toonflow 发出值 |
|------|----------------|
| `model` | `model.modelName`（DB 导入名，如 `gpt-image-2`） |
| `prompt` | 调用方 prompt |
| `n` | **固定 `1`** |
| `size` | `resolveOpenAiPixelSize(config)`（默认链 → `1024x1024`） |
| `quality` | `inputValues.quality` 或 `"auto"` |
| `output_format` | `inputValues.output_format` 或 `"png"` |
| `background` | **硬编码 `"auto"`** |
| `moderation` | **未发送** |
| `response_format` | **未发送** |

**imageTest 入口**：`POST /api/setting/vendorConfig/modelTest/imageTest` → `u.Ai.Image(\`${id}:${modelName}\`).run(...)`（`imageTest.ts:48-61`）。

#### Q08 — model 字段如何传递、有无映射

| 环节 | 行为 |
|------|------|
| imageTest | URL 式 key `third_party_image_api:gpt-image-2`，`modelName` 来自请求体（`imageTest.ts:21`, `48`） |
| ai.ts | `getVendorTemplateFn` 按 `modelName` 查 DB 模型列表，**无别名映射**（`ai.ts:119-125`） |
| vendor | body 中 **`model: model.modelName`** 原样发出（`third_party_image_api.ts:291`） |

对比 snapai：snapai CLI `gpt-image-2` → 仍解析为 **`gpt-image-2`**（`openai.ts:18`）；Toonflow 若 DB 中 `modelName` 为 `gpt-image-2`，HTTP 层 **一致**。

#### Q09 — size 最终值与 gpt-image-2 兼容性

优先级（`third_party_image_api.ts:178-189`）：

1. `inputValues.defaultSize`（模板默认 **`1024x1024`**，`130`）
2. 测试页 `openAiSize`（`imageTest.ts:47-53`）
3. `mapImageSize(size, aspectRatio)`
4. 兜底 `1024x1024`

imageTest 默认 **`aspectRatio=1:1`**（`imageTest.ts:52`），与 snapai 固定 `1024x1024` **兼容**。

#### Q10 — Authorization header 格式

```text
Authorization: Bearer <apiKey>
Content-Type: application/json
```

**依据**：`third_party_image_api.ts:139`, `150` — Key 会先去掉已有 `Bearer ` 前缀再拼接。

加载：运行时从 DB `o_vendorConfig.inputValues` 合并（`ai.ts:130`）。

---

### 差异诊断

#### Q11 — snapai 与 Toonflow HTTP 层差异列表

| # | 维度 | snapai | Toonflow | 可能影响 gpt-image-2 |
|---|------|--------|----------|----------------------|
| 1 | 客户端 | OpenAI SDK v4 | 手写 `axios.post` | 低（同 path 即可） |
| 2 | **`moderation`** | **始终发送** `auto`/`low` | **不发送** | **中** — rcouyi 可能对 gpt-image-2 强制要求 |
| 3 | `background` | 可配置；gpt-image-2 禁 transparent | **硬编码 `"auto"`** | 低（auto 两边一致） |
| 4 | `response_format` | 未显式设置（SDK 默认） | 未设置 | 低–中 |
| 5 | `n` | 1–10 | 固定 1 | 低 |
| 6 | `size` | 固定 1024x1024 | 可配置，默认 1024x1024 | 低（配置正确时一致） |
| 7 | `model` | 别名表 → OpenAI ID | DB `modelName` 直传 | 低（均为 `gpt-image-2` 时一致） |
| 8 | Base URL | SDK + `OPENAI_BASE_URL`  env | `inputValues.baseUrl` | 低（同为 rcouyi /v1 时一致） |
| 9 | 返回处理 | 仅 `b64_json` | `b64_json` / `base64` / `url` 均可 | 不影响 401 |
| 10 | 错误码语义 | SDK 抛错 | axios + 上游 JSON | **401 更像鉴权/路由，不像 size** |

**关于用户报告的 HTTP 401**：

- `invalid_api_key` 通常表示 **Key / Authorization / 网关路由**，而非 `size_not_supported`（一般为 400）。
- 在 **gpt-image-1.5 已成功** 的前提下，Toonflow 的 `Authorization` 与 `baseUrl` 对同一供应商应相同；**更可疑的是 body 字段差异（尤其缺少 `moderation`）或 rcouyi 对 `gpt-image-2` 的独立鉴权策略**，需在 Apifox 抓包与 Toonflow 日志逐字段对比。

#### Q12 — 能否仅改 vendorConfig.inputValues 绕过差异

| 字段 | inputValues 能否对齐 snapai | 说明 |
|------|----------------------------|------|
| `baseUrl` | ✅ | 已有 |
| `apiKey` | ✅ | 已有 |
| `defaultSize` | ✅ | 可设 `1024x1024` |
| `quality` | ✅ | 可设 `auto` |
| `output_format` | ✅ | 可设 `png` |
| `moderation` | ❌ | **vendor 模板无此 input，代码未读** |
| `background` | ❌ | **代码硬编码 `auto`**（虽与 snapai 默认一致） |
| `response_format` | ❌ | 无 input，代码未发 |
| `model` 别名 | ❌ | 需在 DB 模型名即为 `gpt-image-2` |

**结论**：**不能**指望仅改 inputValues 完整对齐 snapai；对 **401** 尤其如此。最多对齐 `size/quality/output_format`；若 rcouyi 要求 `moderation`，必须 **方案 B**。

---

## 4. snapai 协议摘要 + curl 等价

```bash
# snapai 等价的 gpt-image-2 请求（对接 rcouyi 时替换 host）
curl -sS -X POST 'https://api.rcouyi.com/v1/images/generations' \
  -H 'Authorization: Bearer sk-YOUR_RCOUYI_KEY' \
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

**来源字段**：`openai.ts:68-81`, `20`, `14-18`；path 来自 SDK `images.generate`（`openai.ts:83`）。

---

## 5. Toonflow 现状摘要 + curl 等价

```bash
# Toonflow third_party_image_api（openai_images）当前实际发出
curl -sS -X POST 'https://api.rcouyi.com/v1/images/generations' \
  -H 'Authorization: Bearer sk-YOUR_RCOUYI_KEY' \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "gpt-image-2",
    "prompt": "a simple red apple on white background",
    "n": 1,
    "size": "1024x1024",
    "quality": "auto",
    "output_format": "png",
    "background": "auto"
  }'
```

**来源**：`third_party_image_api.ts:285-300`, `137-151`；测试入口 `imageTest.ts:48-61`。

---

## 6. 差异表（汇总）

| 字段 | snapai | Toonflow | 对齐方式 |
|------|--------|----------|----------|
| POST `/v1/images/generations` | ✅ | ✅ | 已一致 |
| `Authorization: Bearer` | ✅ | ✅ | 已一致 |
| `model=gpt-image-2` | ✅ | ✅（DB 名正确时） | 确认模型导入名 |
| `size=1024x1024` | ✅ 固定 | ✅ 默认 | `defaultSize` |
| `quality=auto` | ✅ | ✅ | `quality` input |
| `output_format=png` | ✅ | ✅ | `output_format` input |
| `background=auto` | ✅ | ✅ 硬编码 | 无需改 |
| **`moderation=auto`** | ✅ | ❌ 缺失 | **需改代码** |
| `response_format` | SDK 默认 | 未发 | 可选方案 B |
| 客户端 | OpenAI SDK | axios | 可忽略 |

---

## 7. 修复方案建议

### 方案 A：仅改 inputValues（零代码）

**可做**：

```text
defaultSize = 1024x1024
quality = auto
output_format = png
baseUrl = https://api.rcouyi.com/v1
providerMode = openai_images
submitPath = /images/generations
```

**验证 DB 模型名** 为精确 `gpt-image-2`（非 `gpt-2` 等）。

**局限**：无法补上 **`moderation`**；无法解释多数 **401**（若 Apifox 成功请求含 `moderation` 而 Toonflow 不含，则 A **不够**）。

**适用**：先排除 size/quality 问题；或 Apifox 抓包证明 body 与 Toonflow 完全一致仍 401 → 转查 Key 权限。

### 方案 B：改 `third_party_image_api.ts`（推荐下一步）

**最小改动建议**（仍不碰 `ai.ts` 主链路）：

1. 增加可选 input `moderation`（默认 `auto`），写入 body — 对齐 snapai `openai.ts:81`
2. （可选）增加 `response_format` input，默认 `b64_json`，与 snapai 响应处理一致
3. （可选）`background` 改为读 inputValues，默认 `auto`；对 `gpt-image-2` 拒绝 `transparent`（对齐 snapai `125-128`）
4. 401 时错误文案提示：对比 Apifox 请求体是否含 `moderation`、模型名是否为 `gpt-image-2`

**不推荐**：为 gpt-image-2 单独换 path（snapai 证明同 `/images/generations`）。

---

## 8. 完成判定报告

| 项 | 结果 |
|----|------|
| 1. 已扫描 snapai 文件 | 见 §2 表格（4 个文件 + 2 个 Toonflow 文件） |
| 2. 找到 gpt-image-2 调用代码 | ✅ `user/snapai/src/services/openai.ts` |
| 3. 最关键 HTTP 差异（1–3 项） | ① **Toonflow 缺少 `moderation` 字段**；② 其余 body 在 defaultSize=1024x1024 下与 snapai 接近；③ **401 更像鉴权/网关而非 size** |
| 4. 推荐下一步 | **方案 B**（补 `moderation` + Apifox 抓包 diff）；方案 A 仅作排除性尝试 |
| 5. 未修改文件确认 | ✅ 未改任何 `.ts` / `.vue` / `.json` / `user/**` |

---

## 9. 回滚

本文档为纯新增。删除即可：

```powershell
Remove-Item docs-dev\GPT_IMAGE_2_PROTOCOL_REFERENCE.md
```

---

## 10. 不允许 copy snapai 代码

本文档引用 snapai 协议事实用于诊断。**禁止**将 `user/snapai/` 源码片段复制进 `Toonflow-app/data/vendor/` 或任何业务目录；修复应在本项目 vendor 模板内独立实现同等 HTTP 字段。
