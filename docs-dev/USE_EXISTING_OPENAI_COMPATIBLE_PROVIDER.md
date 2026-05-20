# 使用现有 `openai` 供应商连接 OpenAI-Compatible 第三方 API

> 适用场景：DeepSeek、通义千问 OpenAI 兼容端点、本地 Ollama OpenAI 模式、各类中转网关等。  
> 相关扫描文档：[MODEL_PROVIDER_MAP.md](./MODEL_PROVIDER_MAP.md)

---

## 1. 为什么不新增 `openai_compatible`

| 原因 | 说明 |
|------|------|
| **能力已存在** | `Toonflow-app/data/vendor/openai.ts` 名为「OpenAI标准接口」，通过 `createOpenAI({ baseURL, apiKey }).chat(modelName)` 调用第三方 API。 |
| **配置字段齐全** | 设置页已有 `baseUrl`、`apiKey`；可「手动添加模型」填写任意 `modelName`。 |
| **Agent 引用格式固定** | `o_agentDeploy.modelName` 使用 `openai:模型名`，与 `ai.ts` → `getVendorTemplateFn` 链路一致。 |
| **流式与 Tools** | 由 Vercel AI SDK 的 `streamText` / `generateText` 处理，无需新 Provider 类型。 |
| **最小风险** | 不新增 `data/vendor/openai_compatible.ts`、不改 `ai.ts`、不改 Agent 主流程、不改 `package.json`。 |

新增独立 `openai_compatible` 仅在产品需要**单独菜单品牌**、**自动拉 `/models`**、**非 OpenAI 协议**等场景才有意义（见本文 §10）。

---

## 2. 现有 `openai` 供应商如何等价支持第三方 API

Toonflow 模型系统 = **供应商脚本（`data/vendor/openai.ts`）** + **数据库配置（`o_vendorConfig`）** + **Agent 映射（`o_agentDeploy`）**。

对 OpenAI-Compatible 服务，等价关系如下：

| 你的需求 | Toonflow 实现 |
|----------|----------------|
| 自定义 API 地址 | `inputValues.baseUrl`（设置页「请求地址」） |
| 密钥 | `inputValues.apiKey`（设置页「API密钥」） |
| 模型 ID | 在供应商下「手动添加模型」→ `modelName` 字段 |
| Agent 调用 | `openai:{modelName}`，例如 `openai:deepseek-chat` |
| HTTP 协议 | AI SDK 按 OpenAI Chat Completions 格式请求（默认 `POST {baseUrl}/chat/completions`） |
| 流式输出 | `productionAgent` 使用 `u.Ai.Text(...).stream()` |
| 工具调用 | 决策层/子 Agent 传入 `tools`；取决于**第三方是否支持** OpenAI tools 格式 |

**边界：** 本路径仅适用于 **OpenAI Chat Completions 兼容** 的 API，不声称兼容任意私有协议。

---

## 3. 设置路径：模型服务

### 3.1 启动服务（本地开发）

**后端**（需 Node 24 与 SQLite 正常，见 [LOCAL_DEV_NO_AUTH_MODE.md](./LOCAL_DEV_NO_AUTH_MODE.md)）：

```powershell
cd D:\ComfyUIApi\16宫格分镜_\BBBBBBBBBBBB\Toonflow-app
$env:TOONFLOW_LOCAL_DEV="1"
corepack yarn dev
```

**前端：**

```powershell
cd D:\ComfyUIApi\16宫格分镜_\BBBBBBBBBBBB\Toonflow-web
corepack yarn dev
```

浏览器打开：`http://localhost:50188`

### 3.2 配置 OpenAI 标准接口

1. 打开 **设置**（齿轮 / 设置抽屉）。
2. 左侧菜单 → **模型服务**（`vendorConfig`）。
3. 在供应商列表中选择 **OpenAI标准接口**（id 为 `openai`）。
4. 打开右侧 **启用** 开关（`enable = 1`）。
5. 填写必填项：
   - **请求地址（baseUrl）**：第三方根地址，通常以 `/v1` 结尾。
   - **API密钥（apiKey）**：你的密钥（输入框为 password 类型）。
6. 在 **模型设置** 区域点击 **手动添加**，添加文本模型：
   - **显示名称**：任意友好名（如 `DeepSeek Chat`）。
   - **modelName**：第三方 API 要求的模型 ID（如 `deepseek-chat`）。
   - **类型**：文本（text）。
7. 失焦或保存后，配置写入本地数据库 `o_vendorConfig`（`inputValues` + `models` JSON）。

### 3.3 常见配置示例（勿使用真实密钥）

以下 `baseUrl` 仅为格式示例，请替换为你自己的服务商地址：

| 场景 | baseUrl（示例） | apiKey（示例） | modelName（示例） | Agent 使用名 |
|------|-----------------|----------------|-------------------|--------------|
| 自建/中转 OpenAI 兼容 | `https://your-gateway.example.com/v1` | `sk-xxxx` | `gpt-4o` | `openai:gpt-4o` |
| DeepSeek 兼容端点 | `https://api.deepseek.com/v1` | `sk-xxxx` | `deepseek-chat` | `openai:deepseek-chat` |
| 通义等 OpenAI 兼容 | `https://dashscope.aliyuncs.com/compatible-mode/v1` | `sk-xxxx` | `qwen-plus` | `openai:qwen-plus` |
| 本地 Ollama OpenAI 模式 | `http://127.0.0.1:11434/v1` | `ollama` 或留空按服务要求 | `llama3` | `openai:llama3` |

**注意：**

- `baseUrl` 请填用户自己的第三方地址，不要写死到代码里。
- 文档与截图中 **不要** 粘贴真实 `sk-` 密钥。

---

## 4. Agent 配置路径

1. **设置** → **Agent 配置**（`agentConfog`）。
2. 选择模式：
   - **普通（简易）**：主 Agent（如 `productionAgent`）共用一条模型配置。
   - **高级**：可为 `productionAgent:decisionAgent`、子 Agent 等分别配置（一般先用普通模式即可）。
3. 点击 **生产Agent**（或对应卡片）→ **模型配置**。
4. 在模型选择器中选择：**OpenAI标准接口** 下你添加的模型。
5. 保存后，数据库 `o_agentDeploy.modelName` 应为：

```txt
openai:你的modelName
```

例如：`openai:deepseek-chat`。

可选（高级模式）：单独为 `productionAgent:storyboardTableAgent` 等子 Agent 指定同一或不同模型。

---

## 5. 如何测试模型连接

### 5.1 设置页「模型测试」（推荐）

1. **设置** → **模型服务** → **OpenAI标准接口**。
2. 在已添加的文本模型卡片上点击 **测试** / 闪电图标。
3. 在文本模型测试对话框中发送一条简单消息（如 `ping`）。
4. 成功：返回模型回复内容；失败：查看错误提示（网络、401、模型不存在等）。

后端接口：`POST /api/setting/vendorConfig/modelTest/textTest`（会走 `u.Ai.Text('openai:modelName')` 并可能带 tools 探测）。

### 5.2 通过 Agent 一键探测（仅 toonflow 官方）

`agentSetKey` 仅针对 **toonflow** 供应商，不适用于自定义 `openai` 配置，可忽略。

### 5.3 命令行快速检查（可选）

确认后端与数据库正常：

```powershell
# 健康检查
Invoke-RestMethod http://localhost:10588/api/gridDirector/health

# 项目列表（SQLite 正常时应 200，非 ERR_DLOPEN_FAILED）
Invoke-RestMethod -Method Post http://localhost:10588/api/project/getProject -ContentType "application/json" -Body "{}"
```

若 `getProject` 报 `ERR_DLOPEN_FAILED`，先修复 Node 24 + `better-sqlite3` 重装，否则设置无法持久化。

---

## 6. 如何在 productionAgent 中测试普通对话

**先测简单对话，再测宫格 JSON。**

1. 确保已完成 §3、§4，且 `openai` 供应商已 **启用**。
2. 进入 **制作 / production** 工作区，选择项目与集数。
3. 打开右侧 **productionAgent** 聊天框。
4. 发送：

```txt
你好，请用一句话回复：模型连接成功。
```

5. 成功标准：
   - 有正常文本回复，无长时间挂起。
   - 后端日志无 `未找到供应商` / `缺少API Key` / 401 等错误。

若失败，对照 §9 排查后再测 Skill。

---

## 7. 如何再测试 `grid_director_storyboard` Skill

在 **普通对话成功** 之后，在同一聊天框发送：

```txt
请激活 grid_director_storyboard Skill，根据下面故事拆成 16 宫格动画分镜 JSON。

故事：
镇天皇朝颁布禁海令，少年陈七因一枚龙纹玉玺碎片发现禁海真相，决定出海寻找失落的海上秘境。

要求：
- grid_count = 16
- target_total_sec = 180
- grid_layout = 4x4
- JSON keys 必须英文
- 中文剧情、对白、旁白可以放在 value
- 每个 shot 必须包含 prompt_text、negative_prompt、video_prompt
- 只输出 JSON
- 不要 Markdown
- 不要代码块
```

### 成功标准（自检）

- 决策层或子 Agent 出现 **activate_skill** / **grid_director_storyboard**（不一定在第一句正文里）。
- 最终输出为 **纯 JSON**（无 ` ``` ` 包裹）。
- `shots.length === 16`，`duration_sec` 总和约 **180**。
- 每个 shot 含 `prompt_text`、`video_prompt`、`negative_prompt`。

### 若未激活 Skill

可能需增强 `production_agent_decision.md`（仅改 Prompt，不改 TS），见宫格分镜开发计划第四阶段说明；**仍不需要** 新增 `openai_compatible`。

---

## 8. 常见错误

| 现象 | 可能原因 | 处理建议 |
|------|----------|----------|
| 401 / Invalid API Key | `apiKey` 错误或过期 | 在模型服务页重新填写并保存 |
| 404 / model not found | `modelName` 与服务商不一致 | 对照服务商文档修正手动添加的模型 ID |
| Connection refused | `baseUrl` 错误或本机服务未启动 | 检查 URL、端口、是否需 `http://127.0.0.1:...` |
| **baseUrl 少了 `/v1`** | 填了域名根路径 | 改为 `https://host/v1`（以服务商文档为准） |
| **baseUrl 多写了路径** | 如把 `/chat/completions` 写进 baseUrl | baseUrl 一般只到 `/v1`，路径由 SDK 拼接 |
| 模型列表为空 | 供应商未 **启用** | 打开 OpenAI标准接口 左侧开关 |
| Agent 报「未找到部署配置」 | `productionAgent` 未绑定模型 | Agent 配置中选择 `openai:模型名` |
| Tools 相关报错 | 第三方 **不支持** OpenAI function calling | 换支持 tools 的模型/网关，或后续改决策 Prompt 减少 tools |
| Stream 中断 / 超时 | 网关限流、网络、模型过慢 | 换模型、加大超时（`requestConfig`）、检查网关日志 |
| `ERR_DLOPEN_FAILED` | `better-sqlite3` 与 Node 版本不匹配 | 使用 **Node 24** 重装 `node_modules`（见本地环境修复记录） |
| 配置保存了但不生效 | 未启用供应商或 Agent 仍指向旧模型 | 确认 enable=1 且 Agent 配置已保存 |

---

## 9. 推荐操作顺序（当前阶段）

```txt
1. 修好 SQLite / better-sqlite3（Node 24 + 重装依赖）
2. 启动 Toonflow-app + Toonflow-web（本地无鉴权可选 TOONFLOW_LOCAL_DEV=1）
3. 设置 → 模型服务 → OpenAI标准接口 → baseUrl + apiKey + 手动 modelName
4. 设置 → Agent 配置 → productionAgent → openai:模型名
5. 模型测试（文本）通过
6. productionAgent 普通对话：「模型连接成功」
7. productionAgent 宫格 Skill JSON 测试
```

**当前阶段明确不做：**

```txt
❌ 不新增 openai_compatible.ts
❌ 不改 ai.ts
❌ 不改 Agent 主流程
❌ 不改 modelMap / promptManage 业务逻辑
❌ 不改 package.json
❌ 不做「兼容任意私有 API」的假适配
```

---

## 10. 什么时候才需要真的新增 `openai_compatible`

仅在现有 `openai` **单供应商 id** 无法满足产品时，再考虑二开（参见 [MODEL_PROVIDER_MAP.md](./MODEL_PROVIDER_MAP.md) §18）：

| 需求 | 是否需要新 Provider |
|------|---------------------|
| UI 单独显示「自定义第三方 API」品牌 | 可选：复制 `openai.ts` 为 `openai_compatible.ts` 仅改名称 |
| 同一 Toonflow 内配置 **多个** 不同 baseUrl 的 OpenAI 兼容实例 | 需要：每个实例一个 vendor id（`addVendor` 导入 TS）或多次自定义供应商 |
| 自动 `GET /models` 拉模型列表 | 需要：新 API + 前端按钮（`openai` 模板未内置） |
| 支持 **非** OpenAI Chat Completions 协议 | 需要：`custom_http` 或专用 `data/vendor/*.ts` 模板 |
| 增强连接测试（仅 ping、脱敏日志） | 可选：扩展 `modelTest` 路由 |
| 仅连接 DeepSeek / 中转 / Ollama OpenAI 模式 | **不需要**，用本文现有 `openai` 即可 |

---

## 附录：相关文件（只读参考，本轮不修改）

| 用途 | 路径 |
|------|------|
| OpenAI 兼容适配 | `Toonflow-app/data/vendor/openai.ts` |
| 模型调用入口 | `Toonflow-app/src/utils/ai.ts` |
| 供应商工具 | `Toonflow-app/src/utils/vendor.ts` |
| 设置 API | `Toonflow-app/src/routes/setting/vendorConfig/*` |
| 前端设置页 | `Toonflow-web/src/components/setting/components/vendorConfig.vue` |
| Agent 配置页 | `Toonflow-web/src/components/setting/components/agentConfog.vue` |
| 架构扫描 | `docs-dev/MODEL_PROVIDER_MAP.md` |
