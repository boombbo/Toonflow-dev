# Toonflow 模型配置系统扫描（MODEL_PROVIDER_MAP）

> 扫描日期：2026-05-19  
> 范围：仅文档，未修改业务代码。  
> 目标：为「通用 OpenAI-Compatible 第三方 API」二开提供最小侵入方案。

---

## 0. 架构总览（一句话）

Toonflow 的模型系统 = **SQLite 存密钥/启用状态/用户追加模型** + **`data/vendor/{id}.ts` 可执行适配脚本（VM 沙盒）** + **Vercel AI SDK（`generateText` / `streamText`）** + **`o_agentDeploy` 把 Agent 映射到 `{vendorId}:{modelName}`**。

```mermaid
flowchart LR
  UI[设置页 vendorConfig / agentConfog] --> API[routes/setting/*]
  API --> DB[(o_vendorConfig / o_agentDeploy)]
  Agent[scriptAgent / productionAgent] --> Ai[u.Ai.Text]
  Ai --> Resolve[resolveModelName]
  Resolve --> DB
  Ai --> VendorFn[getVendorTemplateFn]
  VendorFn --> VM[vm.ts 执行 data/vendor/id.ts]
  VM --> SDK[@ai-sdk/openai / openai-compatible / ...]
  SDK --> HTTP[第三方 Chat Completions]
```

---

## 1. 模型供应商配置保存在哪里

| 层级 | 路径 / 表 | 内容 |
|------|-----------|------|
| **运行时适配代码** | `Toonflow-app/data/vendor/{vendorId}.ts` | 每个供应商一份 TS 模板，导出 `vendor`、`textRequest`、`imageRequest`、`videoRequest`、`ttsRequest` |
| **内置模板快照** | `Toonflow-app/src/lib/vendor.json` | 由 `scripts/vendor2json.ts` 从 `data/vendor/*.ts` 生成；`fixDB.ts` 启动时用于同步/升级模板 |
| **用户配置（DB）** | 表 `o_vendorConfig` | `id`、`inputValues`（JSON）、`models`（JSON 用户追加模型）、`enable` |
| **Agent 选用哪个模型** | 表 `o_agentDeploy` | `key`（如 `productionAgent`）、`modelName`（`{vendorId}:{modelName}`）、`temperature`、`maxOutputTokens` |
| **全局模式开关** | 表 `o_setting` | `agentUseMode`：`0` 简易（主 Agent 共用模型）/ `1` 高级（子 Agent 独立模型） |

开发环境数据目录：`process.cwd()/data/`（Electron 下为 `userData/data/`），见 `src/utils/getPath.ts`。

**内置供应商 ID（initDB + data/vendor）：**  
`toonflow`、`deepseek`、`atlascloud`、`volcengine`、`minimax`、`openai`、`klingai`、`vidu`、`grsai`、`null`（空模板）。

---

## 2. 供应商配置的数据结构

### 2.1 代码内 `vendor` 对象（`data/vendor/*.ts`）

每个模板遵循同一结构（以 `openai.ts` 为例）：

```typescript
const vendor: VendorConfig = {
  id: "openai",                    // 全局唯一，不可含冒号
  version: "2.0",
  name: "OpenAI标准接口",           // UI 显示名
  author: "Toonflow",
  description: "...",              // Markdown，设置页展示
  icon: "",
  inputs: [                        // 动态表单字段定义
    { key: "apiKey", label: "API密钥", type: "password", required: true },
    { key: "baseUrl", label: "请求地址", type: "url", required: true, placeholder: "…/v1" },
  ],
  inputValues: { apiKey: "", baseUrl: "https://api.openai.com/v1" },
  models: [                        // 模板内置模型列表
    { name: "GPT-4o", modelName: "gpt-4o", type: "text", think: false },
  ],
};
```

模型类型 discriminated union：`text` | `image` | `video` | `tts`（校验见 `addVendor.ts` 的 zod schema）。

### 2.2 数据库 `o_vendorConfig`

```sql
-- initDB.ts
id          TEXT PK   -- 与 data/vendor/{id}.ts 文件名一致
inputValues TEXT       -- JSON 字符串，如 {"apiKey":"sk-...","baseUrl":"https://..."}
models      TEXT       -- JSON 数组，用户通过 UI「手动添加模型」写入
enable      INTEGER    -- 0/1，是否启用
```

**注意：** 历史版本曾在 DB 存 `name`/`inputs`/`author` 等字段，`fixDB.ts` 已 **删除** 这些列；元数据现 **只存在于 `.ts` 模板**。

### 2.3 最终模型列表合并规则

`utils/vendor.ts` → `getModelList(id)`：

1. 从 `.ts` 读取 `vendor.models`（模板默认）
2. 与 DB `o_vendorConfig.models`（用户追加）合并
3. 以 `modelName` 为 key 去重（DB 覆盖同名）

---

## 3. API Key 保存在哪里

- **主路径：** `o_vendorConfig.inputValues` JSON 中的 `apiKey` 键（明文存在本地 SQLite `data/db2.sqlite`）。
- **写入接口：** `POST /api/setting/vendorConfig/updateVendorInputs`（body: `{ id, inputValues }`）。
- **Toonflow 官方一键填 Key：** `POST /api/setting/agentDeploy/agentSetKey` 仅更新 `toonflow` 供应商的 `apiKey`，并探测模型后写入 `o_agentDeploy`。
- **不在：** 环境变量、前端 localStorage（`stores/setting.ts` 的 `baseUrl` 仅是 API 网关地址，不是模型 Key）。

安全现状：无加密 at-rest；日志需避免打印完整 key（当前 `textTest.ts` 有 `console.log` 调试输出，二开时应注意）。

---

## 4. baseUrl 是否已有字段

**已有。**

- 字段名：`baseUrl`（在 `vendor.inputs` 中定义为 `type: "url"`）。
- 默认值因供应商而异，例如：
  - `openai.ts`：`https://api.openai.com/v1`
  - `deepseek.ts`：`https://api.deepseek.com/v1`
- 运行时：`textRequest` 内 `createOpenAI({ baseURL: vendor.inputValues.baseUrl, apiKey })`。
- **没有** 独立的 `chatPath` / `modelsPath` / `apiKeyHeader` 等通用字段；路径由 AI SDK 默认（OpenAI 兼容一般为 `/chat/completions`）。

---

## 5. 模型列表 / 模型映射保存在哪里

| 用途 | 存储 | 说明 |
|------|------|------|
| 供应商下有哪些模型 | `vendor.models` + `o_vendorConfig.models` | 见 §2.3 |
| Agent 用哪个模型 | `o_agentDeploy.modelName` | 格式 **`{vendorId}:{modelName}`**，如 `openai:gpt-4o` |
| 前端模型选择器 | `POST /api/modelSelect/getModelList` | 仅 `enable=1` 的供应商；按 type 过滤 |
| 视频模型 ↔ 提示词 Skill 文件 | `o_modelPrompt` + `data/modelPrompt/**/*.md` | **不是** LLM 路由；是图生视频提示词模板绑定 |

`o_agentDeploy` 字段：`model`（显示用短名）、`modelName`（完整引用）、`vendorId`、`temperature`、`maxOutputTokens`、`disabled`。

---

## 6. Prompt 与模型映射在哪里

两套不同概念，勿混淆：

### 6.1 `promptManage` — 业务 Prompt（DB）

- 表：`o_prompt`（`name`、`type`、`data`、`useData`）
- 路由：`/api/setting/promptManage/getPrompt`、`updatePrompt`
- 用途：事件提取、剧本资产提取、视频提示词生成、音色绑定等 **固定业务 prompt**
- `utils/getPrompts.ts`：仅硬编码 `type=="event"` 的旧版事件提取文案；**主路径是 DB `o_prompt`**

### 6.2 `modelMap` — 视频模型 ↔ Markdown Skill

- 表：`o_modelPrompt`（`vendorId`、`model`、`path`、`fileName`）
- 文件：`data/modelPrompt/` 下 `**/*.md`
- 路由：`modelMap/getImageAndVideoModel`、`bindingPrompt`、`getPromptList`（扫描 md）
- 用途：为 **video 类型模型** 绑定「视频提示词生成」类 Skill，**不决定** Chat LLM 调用

### 6.3 Agent 系统 Prompt

- `productionAgent` / `scriptAgent` 使用 `data/skills/**` 与决策 md，与 `o_prompt` / `modelMap` 分离。

---

## 7. Agent 调用模型时最终走哪个函数

调用链（文本 / Agent）：

```
productionAgent|scriptAgent
  → u.Ai.Text("productionAgent:decisionAgent" | ...)
    → ai.ts AiText.invoke() / stream()
      → resolveModelName(AiType)     // 读 o_agentDeploy + o_setting.agentUseMode
      → getVendorTemplateFn("textRequest", "{id}:{model}")
        → 读 o_vendorConfig.inputValues
        → u.vendor.getCode(id) + u.vm(jsCode)
        → exports.textRequest(model, think, thinkLevel)
          → 返回 AI SDK LanguageModel
      → generateText() / streamText()  // Vercel AI SDK
```

图像 / 视频 / TTS：

```
u.Ai.Image|Video|Audio("{id}:{model}")
  → getVendorTemplateFn("imageRequest"|"videoRequest"|"ttsRequest")
```

**模型名解析：** `modelName.split(/:(.+)/)` → `[vendorId, modelName]`。

---

## 8. 是否已有 OpenAI-compatible 适配

**已有，且是主路径之一。**

| 实现 | 文件 | 方式 |
|------|------|------|
| **OpenAI 标准接口** | `data/vendor/openai.ts` | `createOpenAI({ baseURL, apiKey }).chat(modelName)` |
| **空模板（可复制）** | `data/vendor/null.ts` | 同上，面向 Vibe Coding |
| **OpenAI Compatible 工厂** | `vm.ts` 注入 `createOpenAICompatible` | `volcengine.ts`、`atlascloud.ts` 等用于非标准 body/路径 |
| **DeepSeek 官方** | `deepseek.ts` | `createDeepSeek`（专用 SDK） |

**结论：** 用户要的「只填 baseUrl + apiKey + model」在 **`openai` 供应商** 上已基本满足；无需新造 `openai_compatible` **类型系统**，除非要做 UX 别名或增强（拉 `/models`、自定义 chatPath 等）。

---

## 9. 是否已有自定义 baseUrl 能力

**已有。**

- 所有带 `inputs[].key === "baseUrl"` 的供应商均可在设置页编辑。
- 保存后立即生效（`updateVendorInputs` + 下次 `getVendorTemplateFn` 注入 `inputValues`）。
- 用户还可 **新增自定义供应商**：粘贴/导入 TS（`addVendor` + `vendorConfig.vue` 代码编辑器），见 `null.ts` 模板。

---

## 10. 是否支持 stream

**支持（Agent 层）。**

- `ai.ts` → `AiText.stream()` → `streamText()`（Vercel AI SDK）。
- `productionAgent/index.ts`：`runDecisionAI`、`runSubAgent` 使用 `.stream({ messages, tools })`，消费 `fullStream`。
- **供应商模板不直接处理 SSE**；流式由 AI SDK 对 OpenAI-compatible 端点封装。
- 设置页 **无**  per-vendor「stream 开关」字段；是否流式由 Agent 代码固定为 stream 模式。

---

## 11. 是否支持 tools / function calling

**支持（经 AI SDK）。**

- `ai.ts`：`invoke` / `stream` 接受 `tools`，并设置 `stopWhen: stepCountIs(...)`。
- `productionAgent`：决策层、子 Agent 传入 `tools`（含 `activate_skill`、业务 tools）。
- 测试：`POST /api/setting/vendorConfig/modelTest/textTest` 使用示例 `getWeatherTool` 验证 tools。
- 兼容性取决于 **具体第三方** 是否实现 OpenAI tools 格式；模板层未统一降级，失败时由 SDK 抛错。

---

## 12. 前端设置页面在哪里

入口：`Toonflow-web` 设置抽屉/弹窗 → `src/components/setting/index.vue`

| 菜单 key | 组件 | 功能 |
|----------|------|------|
| `vendorConfig` | `components/setting/components/vendorConfig.vue` | 供应商列表、启用开关、apiKey/baseUrl 表单、手动加模型、模型测试、导入 TS |
| `agentConfog` | `components/setting/components/agentConfog.vue` | Agent ↔ 模型映射（简易/高级）、temperature、maxOutputTokens |
| `modelMap` | `components/setting/components/modelMap.vue` | 视频模型绑定 `modelPrompt` md |
| `promptManage` | `components/setting/components/promptManage.vue` | 编辑 `o_prompt` 业务 prompt |

模型选择复用：`src/components/modelSelect.vue` → `POST /api/modelSelect/getModelList`。

`stores/setting.ts`：**不存** 模型密钥，仅 UI/主题/API 根路径等。

---

## 13. 新增「通用第三方 API」最小改哪些文件

### 方案 A（推荐，最小）：复用现有 `openai` 供应商

**零后端类型改造**，仅操作/文档/可选 UI 文案：

1. 设置 → **模型服务** → 启用 **`openai`（OpenAI标准接口）**
2. 填写 `baseUrl`、`apiKey`
3. **手动添加模型** → `modelName` = 第三方模型 ID（如 `deepseek-chat`）
4. **Agent 配置** → 选择 `openai:deepseek-chat`

可选小改（非必须）：

| 文件 | 改动 |
|------|------|
| `data/vendor/openai.ts` | 补充 description、示例 baseUrl、默认 models 为空引导用户自填 |
| `Toonflow-web` i18n | 将「OpenAI标准接口」副标题改为「OpenAI 兼容 / 自定义第三方 API」 |

### 方案 B：新增供应商 id `openai_compatible`

与 `openai.ts` 相同实现，独立显示名，避免与「真·OpenAI」混淆：

| 文件 | 改动 |
|------|------|
| `data/vendor/openai_compatible.ts` | 复制 `openai.ts`，改 `id`/`name`/`description` |
| `src/lib/vendor.json` | 运行 `node scripts/vendor2json.ts` 重新生成（**构建/发布步骤**，非运行时必改） |
| `src/lib/fixDB.ts` | 可选：在 `defList` 同步逻辑中自动插入 DB 行（或依赖 `tempOnsert` 首次启动） |
| `src/lib/initDB.ts` | 可选：`o_vendorConfig` 种子增加一行（新库） |

**不建议** 新建独立后端模块或改 `ai.ts` 主流程。

### 方案 C：增强项（第二阶段，非最小）

| 能力 | 涉及 |
|------|------|
| `GET /models` 拉列表 | 新路由或扩展 `vendorConfig`；前端 `vendorConfig.vue` 加按钮 |
| `chatPath` / `extraHeaders` | 扩展 `vendor.inputs` + `textRequest` 使用 `createOpenAICompatible` + custom `fetch` |
| 连接测试（仅 ping） | 扩展 `modelTest/textTest` 或新增 `connectionTest` 路由 |
| Agent 级 stream 开关 | 改 `ai.ts` / Agent（范围大，非最小） |

---

## 14. 是否需要新增 data/vendor 模板

| 方案 | 是否需要 |
|------|----------|
| A 复用 `openai` | **否** |
| B 新 id `openai_compatible` | **是**，新增 `data/vendor/openai_compatible.ts` + 更新 `vendor.json` |
| 用户自定义私有协议 | **是**，走现有 `addVendor` 导入 TS，**不要** 冒充 OpenAI-compatible |

---

## 15. 是否需要修改数据库初始化

| 场景 | 是否需要 |
|------|----------|
| 方案 A | **否**（`openai` 已在 initDB 种子中） |
| 方案 B 新供应商 | **可选**：`initDB` 加种子行；或仅靠 `fixDB.ts` 的 `tempOnsert` 在首次迁移时插入 |
| 新表/新列存 chatPath 等 | **否**（应放进 `inputValues` JSON 或 `.ts` 模板，避免改表） |

---

## 16. 是否需要迁移旧配置

**一般不需要。**

- 已有 `openai` 行：`inputValues` / `models` 继续有效。
- 若新增 `openai_compatible`：与 `openai` 并行，用户手动启用并填 Key，**无自动迁移**。
- `fixDB` 会按 `vendor.json` **覆盖升级** 部分供应商 `.ts` 文件版本（如 volcengine、minimax），**不覆盖** `inputValues`。

---

## 17. 风险点

| 风险 | 说明 |
|------|------|
| **误以为兼容一切 API** | 仅 OpenAI Chat Completions 形态；Anthropic-native、私有 JSON-RPC 需单独模板 |
| **baseUrl 末尾 `/v1`** | 用户常填错；需在 UI placeholder 与错误提示中强调 |
| **密钥明文落盘** | SQLite 本地存储；Electron 分发需注意设备安全 |
| **VM 执行供应商代码** | 自定义 TS 供应商为高风险能力（已有双重确认 UI） |
| **模型名冒号** | `vendorId` 不能含 `:`；`modelName` 通过 `id:name` 拼接解析 |
| **enable 未开** | `getModelList` 只返回 `enable=1`；Agent 配置了禁用供应商会报错 |
| **Node 版本与 native 模块** | 与模型无关，但影响 DB/API 可用（见本地 dev 文档） |
| **tools 不支持** | 部分兼容网关不实现 tools，productionAgent 决策层可能失败 |
| **vendor.json 与 data/vendor 不同步** | 改 `.ts` 后需跑 `vendor2json` 再发布，否则 fixDB 升级可能回滚旧模板 |

---

## 18. 推荐实施方案

### 第一阶段（当前）：扫描结论 ✅

**不要重造模型系统。** 先让团队知道：**内置 `openai` 供应商 = OpenAI-Compatible Provider**。

操作 checklist（用户/测试）：

1. 设置 → 模型服务 → 启用 `openai`
2. Base URL：`https://api.deepseek.com/v1`（示例）
3. API Key：填写密钥
4. 手动添加文本模型：`modelName` = `deepseek-chat`
5. 模型测试（文本）通过
6. Agent 配置 → `productionAgent` 选 `openai:deepseek-chat`
7. productionAgent 发一条普通对话验证

### 第二阶段（二开，仍保持最小）

1. **优先方案 A**：文档化 + 可选改 `openai.ts` 文案/空 models 列表  
2. 若产品需要独立入口：**方案 B** 增加 `openai_compatible.ts`（实现与 openai 相同）  
3. **连接测试**：复用 `modelTest/textTest`，前端「测试连接」已存在（`TextModelTest.vue`）  
4. **可选**：`GET /models` 拉取 → 新 API + `vendorConfig.vue` 按钮（失败则回退手动填 model ID）  
5. **明确不做**：新 `gridDirector` 后端、改 `package.json`、改 Agent TS 主流程（除非 tools/stream 必须修）

### 与「只填 baseUrl + 密钥」的产品差距

| 需求 | 现状 |
|------|------|
| baseUrl | ✅ `inputValues.baseUrl` |
| apiKey | ✅ `inputValues.apiKey` |
| model ID | ⚠️ 需「手动添加模型」一步（UI 已有） |
| 自动模型列表 | ❌ 未实现 `/models` |
| stream 开关 | ❌ 无 UI；Agent 固定 stream |
| chatPath 自定义 | ❌ 使用 SDK 默认 |

**建议保留手动 model ID**，与你的产品判断一致。

---

## 附录 A：关键后端路由

| 路由 | 文件 |
|------|------|
| `POST /setting/vendorConfig/getVendorList` | `getVendorList.ts` |
| `POST /setting/vendorConfig/updateVendorInputs` | `updateVendorInputs.ts` |
| `POST /setting/vendorConfig/enableVendor` | `enableVendor.ts` |
| `POST /setting/vendorConfig/addVendorModel` | `addVendorModel.ts` |
| `POST /setting/vendorConfig/modelTest/textTest` | `modelTest/textTest.ts` |
| `POST /setting/agentDeploy/deployAgentModel` | `deployAgentModel.ts` |
| `POST /modelSelect/getModelList` | `modelSelect/getModelList.ts` |

## 附录 B：关键依赖（package.json 已有，二开勿重复加）

- `ai`（Vercel AI SDK）
- `@ai-sdk/openai`
- `@ai-sdk/openai-compatible`
- `@ai-sdk/deepseek` 等专用 provider

## 附录 C：`getPrompts.ts` 说明

- 路径：`Toonflow-app/src/utils/getPrompts.ts`
- 作用：仅 `event` 类型硬编码字符串；**不是**模型供应商或 Agent 模型路由。
- 主业务 prompt：`o_prompt` 表 + `promptManage` UI。

---

**扫描完成。下一步：** 按 §18 在 UI 验证现有 `openai` 供应商；若产品坚持独立「OpenAI-Compatible」品牌项，再执行方案 B 与 `docs-dev/OPENAI_COMPATIBLE_PROVIDER.md`（第二阶段文档）。
